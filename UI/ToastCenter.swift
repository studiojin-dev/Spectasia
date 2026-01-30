import SwiftUI

@MainActor
final class ToastCenter: ObservableObject {
    @Published var message: String?

    func show(_ message: String, duration: TimeInterval = 2.0) {
        self.message = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self else { return }
            if self.message == message {
                self.message = nil
            }
        }
    }
}
