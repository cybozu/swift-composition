import Composition

struct TestableEffectExecutor: EffectExecutable {
    let coordinator: ContinuationCoordinator

    func perform(_ effect: @MainActor @escaping () async -> Void) async {
        if coordinator.hasReenteredEffect {
            await yield()
            await effect()
        } else {
            coordinator.hasReenteredEffect = true
            await effect()
        }
    }

    func yield() async {
        await withCheckedContinuation { continuation in
            coordinator.executorContinuation = continuation
            coordinator.dispatcherContinuation.resumeOnce()
        }
    }
}
