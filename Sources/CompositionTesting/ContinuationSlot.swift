import Synchronization

final class ContinuationSlot: Sendable {
    private let continuation = Mutex<CheckedContinuation<Void, Never>?>(nil)

    var isEmpty: Bool {
        continuation.withLock { $0 == nil }
    }

    func hold(_ newValue: CheckedContinuation<Void, Never>) {
        continuation.withLock { $0 = newValue }
    }

    func resume() {
        continuation.withLock { $0.take() }?.resume()
    }

    func clear() {
        continuation.withLock { $0 = nil }
    }
}
