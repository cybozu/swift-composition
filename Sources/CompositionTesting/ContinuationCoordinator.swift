import Synchronization

final class ContinuationCoordinator: Sendable {
    let dispatcher = ContinuationSlot()
    let executor = ContinuationSlot()
    private let _hasReenteredEffect = Mutex<Bool>(false)

    var hasReenteredEffect: Bool {
        get { _hasReenteredEffect.withLock { $0 } }
        set { _hasReenteredEffect.withLock { $0 = newValue } }
    }

    func reset() {
        dispatcher.clear()
        executor.clear()
        _hasReenteredEffect.withLock { $0 = false }
    }
}
