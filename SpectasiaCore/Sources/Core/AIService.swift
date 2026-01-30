import Foundation
import Vision

// MARK: - Constants

/// Maximum number of classification labels to return
private let maxClassificationLabels = 5

// MARK: - Protocol

/// Protocol for image analysis (allows mocking in tests)
public protocol ImageAnalyzing {
    func analyze(imageAt url: URL, language: AppLanguage) throws -> [String]
}

// MARK: - Service

/// Service for AI-powered image analysis using Vision Framework
@available(macOS 10.15, *)
public class AIService {
    private let analyzer: ImageAnalyzing

    public init(analyzer: ImageAnalyzing? = nil) {
        // Use provided analyzer or create default
        self.analyzer = analyzer ?? VisionImageAnalyzer()
    }

    /// Analyze an image and return tags
    /// - Parameters:
    ///   - url: URL of the image file
    ///   - language: Language for tags
    /// - Returns: Array of tag strings
    /// - Throws: AIServiceError if analysis fails
    public func analyze(imageAt url: URL, language: AppLanguage = .english) throws -> [String] {
        return try analyzer.analyze(imageAt: url, language: language)
    }
}

// MARK: - Default Vision Implementation

/// Default implementation using Vision Framework
@available(macOS 10.15, *)
class VisionImageAnalyzer: ImageAnalyzing {
    func analyze(imageAt url: URL, language: AppLanguage) throws -> [String] {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AIServiceError.fileNotFound
        }

        // Load image
        guard let image = UIImage(contentsOfFile: url.path) else {
            throw AIServiceError.cannotLoadImage
        }

        // Perform classification
        return try performClassification(on: image.cgImage, language: language)
    }

    private func performClassification(on cgImage: CGImage, language: AppLanguage) throws -> [String] {
        var tags: [String] = []

        // Create classification request
        let request = VNClassifyImageRequest()
        request.revision = VNClassifyImageRequestRevision1

        // Create handler
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // Perform request
        try handler.perform([request])

        // Extract results
        guard let observations = request.results else {
            return tags
        }

        // Convert observations to tags
        for observation in observations.prefix(maxClassificationLabels) {
            let label = observation.identifier
            tags.append(label.lowercased())
        }

        // Localize if needed
        if language == .korean {
            tags = tags.map { localizeTag($0, to: .korean) }
        }

        return tags
    }

    private func localizeTag(_ tag: String, to language: AppLanguage) -> String {
        // Simple tag localization (in production, use proper localization)
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
