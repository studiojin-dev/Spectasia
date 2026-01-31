import Foundation
import Vision

// MARK: - Constants

/// Maximum number of classification labels to return
private let maxClassificationLabels = 6

// MARK: - Models

/// Represents the detailed output of an AI analysis run
@available(macOS 10.15, *)
public struct AIAnalysisResult: Sendable {
    public let tags: [String]
    public let animals: [String]
    public let objects: [String]
    public let faceCount: Int
    public let mood: String?

    public init(
        tags: [String],
        animals: [String],
        objects: [String],
        faceCount: Int,
        mood: String?
    ) {
        self.tags = tags
        self.animals = animals
        self.objects = objects
        self.faceCount = faceCount
        self.mood = mood
    }
}

// MARK: - Protocol

/// Protocol for image analysis (allows mocking in tests)
@available(macOS 10.15, *)
public protocol ImageAnalyzing {
    func analyze(imageAt url: URL, language: AppLanguage) throws -> AIAnalysisResult
}

// MARK: - Service

/// Service for AI-powered image analysis using Vision Framework
@available(macOS 10.15, *)
public class AIService {
    private let analyzer: ImageAnalyzing

    public init(analyzer: ImageAnalyzing? = nil) {
        self.analyzer = analyzer ?? VisionImageAnalyzer()
    }

    /// Analyze an image and return tags
    public func analyze(imageAt url: URL, language: AppLanguage = .english) throws -> [String] {
        try analyzer.analyze(imageAt: url, language: language).tags
    }

    /// Analyze an image and return the full AI analysis result
    public func analyzeDetailed(imageAt url: URL, language: AppLanguage = .english) throws -> AIAnalysisResult {
        try analyzer.analyze(imageAt: url, language: language)
    }
}

// MARK: - Default Vision Implementation

/// Default implementation using Vision Framework
@available(macOS 10.15, *)
class VisionImageAnalyzer: ImageAnalyzing {
    func analyze(imageAt url: URL, language: AppLanguage) throws -> AIAnalysisResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AIServiceError.fileNotFound
        }

        guard let image = UIImage(contentsOfFile: url.path) else {
            throw AIServiceError.cannotLoadImage
        }

        return try performDetailedAnalysis(on: image.cgImage, language: language)
    }

    private func performDetailedAnalysis(on cgImage: CGImage, language: AppLanguage) throws -> AIAnalysisResult {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        let classificationRequest = VNClassifyImageRequest()
        classificationRequest.revision = VNClassifyImageRequestRevision1

        let faceRequest = VNDetectFaceRectanglesRequest()

        var animalRequest: VNRecognizeAnimalsRequest?
        if #available(macOS 12.0, *) {
            let request = VNRecognizeAnimalsRequest()
            request.revision = VNRecognizeAnimalsRequestRevision1
            animalRequest = request
        }

        var requests: [VNRequest] = [classificationRequest, faceRequest]
        if let animalRequest { requests.append(animalRequest) }

        try handler.perform(requests)

        let tags = extractClassificationTags(from: classificationRequest, language: language)
        let faceCount = faceRequest.results?.count ?? 0
        let animals = (animalRequest?.results as? [VNRecognizedObjectObservation])?
            .compactMap { $0.labels.first?.identifier.lowercased() } ?? []
        let objects = deriveObjectTags(from: tags, excluding: animals)

        let mood = determineMood(from: tags, language: language)

        return AIAnalysisResult(
            tags: Array(tags.prefix(maxClassificationLabels)),
            animals: Array(Set(animals)).sorted(),
            objects: Array(Set(objects)).sorted(),
            faceCount: faceCount,
            mood: mood
        )
    }

    private func extractClassificationTags(from request: VNClassifyImageRequest, language: AppLanguage) -> [String] {
        let observations = request.results ?? []
        let rawTags = observations.prefix(maxClassificationLabels).map { $0.identifier.lowercased() }
        if language == .korean {
            return rawTags.map { localizeTag($0) }
        }
        return rawTags
    }

    private func determineMood(from tags: [String], language: AppLanguage) -> String? {
        let moodMap: [String: (english: String, korean: String)] = [
            "sunset": ("Quiet", "고요함"),
            "sunrise": ("Fresh", "상쾌함"),
            "night": ("Moody", "몽환적"),
            "storm": ("Dramatic", "극적인"),
            "snow": ("Calm", "차분한"),
            "rain": ("Cozy", "포근한"),
            "smile": ("Joyful", "기쁨"),
            "party": ("Lively", "활기찬"),
            "city": ("Urban", "도시적인"),
            "beach": ("Relaxed", "편안한"),
            "mountain": ("Adventurous", "모험적인"),
            "forest": ("Wild", "야생의"),
            "dog": ("Playful", "명랑한"),
            "cat": ("Serene", "평온한"),
        ]

        for tag in tags {
            if let mood = moodMap[tag.lowercased()] {
                return language == .korean ? mood.korean : mood.english
            }
        }

        return nil
    }

    private func deriveObjectTags(from tags: [String], excluding animals: [String]) -> [String] {
        let animalSet = Set(animals.map { $0.lowercased() })
        let objectVocabulary: Set<String> = [
            "car", "building", "tree", "computer", "phone", "boat", "bicycle", "chair",
            "table", "door", "window", "bag", "cup", "bottle", "desk", "camera", "lamp"
        ]
        return Array(Set(tags.filter { objectVocabulary.contains($0.lowercased()) && !animalSet.contains($0.lowercased()) }))
            .sorted()
    }

    private func localizeTag(_ tag: String) -> String {
        let translations: [String: String] = [
            "nature": "자연",
            "landscape": "풍경",
            "sunset": "일몰",
            "sky": "하늘",
            "water": "물",
            "mountain": "산",
            "forest": "숲",
            "beach": "해변",
            "city": "도시",
            "building": "건물",
            "person": "사람",
            "animal": "동물",
            "dog": "개",
            "cat": "고양이",
            "car": "자동차",
            "food": "음식",
            "flower": "꽃",
            "tree": "나무",
            "indoors": "실내",
            "outdoors": "실외",
        ]

        return translations[tag.lowercased()] ?? tag
    }
}

// MARK: - UIImage Helper

/// Simple UIImage wrapper for Core Graphics image
struct UIImage {
    let cgImage: CGImage

    init?(contentsOfFile path: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        self.cgImage = cgImage
    }
}

// MARK: - Errors

public enum AIServiceError: Error {
    case fileNotFound
    case cannotLoadImage
    case analysisFailed
}
