import SwiftUI

@MainActor
final class ToastCenter: ObservableObject {
    @Published var message: String?
    @Published var statusMessage: String?
    private var queue: [String] = []
    private var isShowing = false
    private var lastShownAt: Date?
    private let minInterval: TimeInterval = 0.8
    private let maxQueueDepth = 5
    private var suppressedCount = 0

    func show(_ message: String, duration: TimeInterval = 2.0) {
        if isShowing {
            enqueue(message)
            return
        }

        let now = Date()
        if let lastShownAt, now.timeIntervalSince(lastShownAt) < minInterval {
            enqueue(message)
            return
        }

        display(message, duration: duration)
    }

    func setStatus(_ message: String?) {
        statusMessage = message
    }

    private func enqueue(_ message: String) {
        if queue.count >= maxQueueDepth {
            suppressedCount += 1
            queue[queue.count - 1] = String(format: NSLocalizedString("Notifications suppressed (+%lld)", comment: "Toast shown when too many notifications are queued."), suppressedCount)
            return
        }
        queue.append(message)
        if !isShowing {
            Task { [weak self] in
                await self?.dequeueAndShow()
            }
        }
    }

    private func dequeueAndShow() async {
        guard !isShowing, let next = queue.first else { return }
        queue.removeFirst()
        display(next, duration: 2.0)
    }

    private func display(_ message: String, duration: TimeInterval) {
        self.message = message
        self.isShowing = true
        self.lastShownAt = Date()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard let self else { return }
            if self.message == message {
                self.message = nil
            }
            self.isShowing = false
            if self.queue.isEmpty {
                self.suppressedCount = 0
            }
            await self.dequeueAndShow()
        }
    }
}
