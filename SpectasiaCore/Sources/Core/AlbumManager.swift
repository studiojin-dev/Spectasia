import Foundation

/// Manages album definitions (saved + derived) that group images by tags, dates, and context.
@available(macOS 10.15, *)
@MainActor
public final class AlbumManager: ObservableObject {
    public struct AlbumDefinition: Codable, Identifiable, Hashable, Sendable {
        public let id: UUID
        public var name: String
        public let category: AlbumCategory
        public var filter: AlbumFilter
        public var coverPath: String?
        public let createdAt: Date
        public var updatedAt: Date
        public var isDerived: Bool

        public init(
            id: UUID = UUID(),
            name: String,
            category: AlbumCategory,
            filter: AlbumFilter,
            coverPath: String? = nil,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            isDerived: Bool = false
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.filter = filter
            self.coverPath = coverPath
            self.createdAt = createdAt
            self.updatedAt = updatedAt
            self.isDerived = isDerived
        }
    }

    public enum AlbumCategory: String, Codable, CaseIterable, Sendable {
        case tag
        case date
        case location
        case people
        case pets
        case custom
    }

    public enum AlbumFilter: Codable, Hashable, Sendable {
        case tags([String])
        case date(year: Int, month: Int?, day: Int?)
        case location(String)
        case people(String)
        case pets(String)

        private enum CodingKeys: String, CodingKey {
            case type, tags, year, month, day, value
        }

        private enum FilterType: String, Codable {
            case tags, date, location, people, pets
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .tags(let tags):
                try container.encode(FilterType.tags, forKey: .type)
                try container.encode(tags, forKey: .tags)
            case let .date(year, month, day):
                try container.encode(FilterType.date, forKey: .type)
                try container.encode(year, forKey: .year)
                try container.encodeIfPresent(month, forKey: .month)
                try container.encodeIfPresent(day, forKey: .day)
            case .location(let value):
                try container.encode(FilterType.location, forKey: .type)
                try container.encode(value, forKey: .value)
            case .people(let value):
                try container.encode(FilterType.people, forKey: .type)
                try container.encode(value, forKey: .value)
            case .pets(let value):
                try container.encode(FilterType.pets, forKey: .type)
                try container.encode(value, forKey: .value)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(FilterType.self, forKey: .type)
            switch type {
            case .tags:
                let tags = try container.decode([String].self, forKey: .tags)
                self = .tags(tags)
            case .date:
                let year = try container.decode(Int.self, forKey: .year)
                let month = try container.decodeIfPresent(Int.self, forKey: .month)
                let day = try container.decodeIfPresent(Int.self, forKey: .day)
                self = .date(year: year, month: month, day: day)
            case .location:
                let value = try container.decode(String.self, forKey: .value)
                self = .location(value)
            case .people:
                let value = try container.decode(String.self, forKey: .value)
                self = .people(value)
            case .pets:
                let value = try container.decode(String.self, forKey: .value)
                self = .pets(value)
            }
        }
    }

    @Published public private(set) var albums: [AlbumDefinition]

    private let storageURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(rootDirectory: URL) {
        self.storageURL = rootDirectory.appendingPathComponent("albums.json")
        self.albums = []
        self.encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        loadAlbumsAsync()
    }

    public func createAlbum(
        name: String,
        category: AlbumCategory,
        filter: AlbumFilter,
        coverPath: String? = nil
    ) {
        var definition = AlbumDefinition(
            name: name,
            category: category,
            filter: filter,
            coverPath: coverPath
        )
        definition.updatedAt = Date()
        albums.append(definition)
        persist()
    }

    public func renameAlbum(id: UUID, to newName: String) {
        guard let index = albums.firstIndex(where: { $0.id == id }) else { return }
        albums[index].name = newName
        albums[index].updatedAt = Date()
        persist()
    }

    public func deleteAlbum(id: UUID) {
        albums.removeAll { $0.id == id }
        persist()
    }

    public func mergeAlbums(into targetID: UUID, sources: [UUID]) {
        guard let targetIndex = albums.firstIndex(where: { $0.id == targetID }) else { return }
        let sourceFilters = albums.filter { sources.contains($0.id) }
        var tagSet = Set(albums[targetIndex].filter.tagList())
        for source in sourceFilters {
            tagSet.formUnion(source.filter.tagList())
        }
        albums[targetIndex].filter = .tags(Array(tagSet))
        albums[targetIndex].updatedAt = Date()
        deleteAlbumList(sourceIDs: sources)
        persist()
    }

    private func deleteAlbumList(sourceIDs: [UUID]) {
        for id in sourceIDs {
            albums.removeAll { $0.id == id }
        }
    }

    public func setCover(id: UUID, path: String) {
        guard let index = albums.firstIndex(where: { $0.id == id }) else { return }
        albums[index].coverPath = path
        albums[index].updatedAt = Date()
        persist()
    }

    public func matchingImages(
        for album: AlbumDefinition,
        from images: [SpectasiaImage]
    ) -> [SpectasiaImage] {
        images.filter { matches(filter: album.filter, image: $0) }
    }

    public func derivedAlbums(from images: [SpectasiaImage]) -> [AlbumDefinition] {
        var derived: [AlbumDefinition] = []
        derived.append(contentsOf: deriveTagAlbums(from: images))
        derived.append(contentsOf: deriveDateAlbums(from: images))
        derived.append(contentsOf: deriveLocationAlbums(from: images))
        derived.append(contentsOf: deriveEntityAlbums(from: images, prefix: "person:", category: .people))
        derived.append(contentsOf: deriveEntityAlbums(from: images, prefix: "pet:", category: .pets))
        return derived
    }

    private func deriveTagAlbums(from images: [SpectasiaImage]) -> [AlbumDefinition] {
        let tagCounts = images.flatMap { $0.metadata.tags }.map { $0.lowercased() }
        let ordered = Dictionary(grouping: tagCounts, by: { $0 })
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .prefix(6)
        return ordered.map { (tag, _) in
            AlbumDefinition(
                name: "Tag: \(tag)",
                category: .tag,
                filter: .tags([tag]),
                isDerived: true
            )
        }
    }

    private func deriveDateAlbums(from images: [SpectasiaImage]) -> [AlbumDefinition] {
        let calendar = Calendar.current
        let years = Dictionary(grouping: images) {
            calendar.component(.year, from: $0.metadata.modificationDate)
        }.keys.sorted(by: >)

        return years.map { year in
            AlbumDefinition(
                name: "Year \(year)",
                category: .date,
                filter: .date(year: year, month: nil, day: nil),
                isDerived: true
            )
        }
    }

    private func deriveLocationAlbums(from images: [SpectasiaImage]) -> [AlbumDefinition] {
        let locations = images.flatMap { $0.metadata.tags }
            .filter { $0.lowercased().hasPrefix("loc:") }
            .map { String($0.dropFirst(4)) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let unique = Array(Set(locations)).filter { !$0.isEmpty }
        return unique.map { location in
            AlbumDefinition(
                name: location.capitalized,
                category: .location,
                filter: .location(location),
                isDerived: true
            )
        }
    }

    private func deriveEntityAlbums(from images: [SpectasiaImage], prefix: String, category: AlbumCategory) -> [AlbumDefinition] {
        let entities = images.flatMap { $0.metadata.tags }
            .filter { $0.lowercased().hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let unique = Array(Set(entities)).filter { !$0.isEmpty }
        return unique.map { entity in
            AlbumDefinition(
                name: entity.capitalized,
                category: category,
                filter: category == .people ? .people(entity) : .pets(entity),
                isDerived: true
            )
        }
    }

    private func matches(filter: AlbumFilter, image: SpectasiaImage) -> Bool {
        switch filter {
        case .tags(let tags):
            let imageTags = Set(image.metadata.tags.map { $0.lowercased() })
            return tags.allSatisfy { imageTags.contains($0.lowercased()) }
        case let .date(year, month, day):
            let calendar = Calendar.current
            let comps = calendar.dateComponents([.year, .month, .day], from: image.metadata.modificationDate)
            if comps.year != year { return false }
            if let month, comps.month != month { return false }
            if let day, comps.day != day { return false }
            return true
        case let .location(value):
            return image.metadata.tags.contains(where: {
                $0.lowercased() == "loc:\(value.lowercased())"
            })
        case let .people(value):
            return image.metadata.tags.contains(where: {
                $0.lowercased() == "person:\(value.lowercased())"
            })
        case let .pets(value):
            return image.metadata.tags.contains(where: {
                $0.lowercased() == "pet:\(value.lowercased())"
            })
        }
    }

    private func loadAlbumsAsync() {
        let storage = storageURL
        let decoder = self.decoder
        Task.detached { [self] in
            guard FileManager.default.fileExists(atPath: storage.path) else {
                await self.applyLoadedAlbums([])
                return
            }
            do {
                let data = try Data(contentsOf: storage)
                let decoded = try decoder.decode([AlbumDefinition].self, from: data)
                await self.applyLoadedAlbums(decoded)
            } catch {
                CoreLog.error("Failed to load albums: \(error.localizedDescription)", category: "AlbumManager")
                await self.applyLoadedAlbums([])
            }
        }
    }

    private func persist() {
        let storage = storageURL
        let encoder = self.encoder
        let snapshot = albums
        Task.detached {
            do {
                let data = try encoder.encode(snapshot)
                try data.write(to: storage, options: .atomic)
            } catch {
                CoreLog.error("Failed to persist albums: \(error.localizedDescription)", category: "AlbumManager")
            }
        }
    }

    @MainActor
    private func applyLoadedAlbums(_ definitions: [AlbumDefinition]) {
        albums = definitions
    }
}

@available(macOS 10.15, *)
private extension AlbumManager.AlbumFilter {
    func tagList() -> [String] {
        switch self {
        case .tags(let tags):
            return tags
        case .location(let value):
            return [value]
        case .people(let value):
            return [value]
        case .pets(let value):
            return [value]
        case let .date(year, month, day):
            var components = ["\(year)"]
            if let month { components.append(String(month)) }
            if let day { components.append(String(day)) }
            return components
        }
    }
}
