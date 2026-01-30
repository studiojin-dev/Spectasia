import Foundation

public enum ThumbnailSizeOption: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}
