import Synchronization

final class ContinuationCoordinator: Sendable {
    private let _hasReenteredEffect = Mutex<Bool>(false)
    private let _dispatcherContinuation = Mutex<CheckedContinuation<Void, Never>?>(nil)
    private let _executorContinuation = Mutex<CheckedContinuation<Void, Never>?>(nil)

    var hasReenteredEffect: Bool {
        get { _hasReenteredEffect.withLock { $0 } }
        set { _hasReenteredEffect.withLock { $0 = newValue } }
    }

    var dispatcherContinuation: CheckedContinuation<Void, Never>? {
        get { _dispatcherContinuation.withLock { $0 } }
        set { _dispatcherContinuation.withLock { $0 = newValue } }
    }

    var executorContinuation: CheckedContinuation<Void, Never>? {
        get { _executorContinuation.withLock { $0 } }
        set { _executorContinuation.withLock { $0 = newValue } }
    }

    func reset() {
        _hasReenteredEffect.withLock { $0 = false }
        _dispatcherContinuation.withLock { $0 = nil }
        _executorContinuation.withLock { $0 = nil }
    }
}

extension CheckedContinuation<Void, Never>? {
    mutating func resumeOnce() {
        self?.resume()
        self = nil
    }
}
