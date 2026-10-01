import Composition

/// A testing wrapper for `Composable` stores that gives deterministic control over re-entrant actions.
///
/// `TestStore` can send actions, mutate state directly, and suspend follow-up effects until `resume()` is called.
/// It captures the task-local values bound at its creation, and every action it processes, as well as every state
/// mutation made through `set(_:to:)`, runs with those values.
@MainActor @dynamicMemberLookup
public final class TestStore<Root: Composable, Store: Composable> {
    private let store: Store
    private let coordinator: ContinuationCoordinator
    private let runner: OperationRunner

    /// Creates a root test store.
    ///
    /// - Parameter makeStore: A closure that creates the root store under test.
    public init(makeStore: () -> Store) where Root == Store {
        store = makeStore()
        coordinator = .init()
        runner = .init()
    }

    private init(store: Store, coordinator: ContinuationCoordinator, runner: OperationRunner) {
        self.store = store
        self.coordinator = coordinator
        self.runner = runner
    }

    deinit {
        guard Root.self != Store.self || coordinator.executorContinuation == nil else {
            IssueRecorder.current.record("The test finished but there is a suspended action. Call 'resume()' to resume all expected actions.")
            return
        }
    }

    /// Creates a scoped test store for a non-optional child store.
    ///
    /// - Parameter target: A key path from the current store to a child store.
    /// - Returns: A `TestStore` that targets the child store.
    public func scope<Target: Composable>(to target: KeyPath<Store, Target>) -> TestStore<Root, Target> {
        .init(store: store[keyPath: target], coordinator: coordinator, runner: runner)
    }

    /// Creates a scoped test store for an optional child store.
    ///
    /// - Parameter target: A key path from the current store to an optional child store.
    /// - Returns: A scoped `TestStore` if the child store exists; otherwise `nil`.
    public func scope<Target: Composable>(to target: KeyPath<Store, Target?>) -> TestStore<Root, Target>? {
        store[keyPath: target].map {
            .init(store: $0, coordinator: coordinator, runner: runner)
        }
    }

    /// Performs work on the store under test by sending an action.
    ///
    /// If another action is already suspended, this method records a test issue and returns.
    ///
    /// - Parameter action: The action to send.
    public func send(_ action: Store.Action) async {
        guard coordinator.executorContinuation == nil else {
            IssueRecorder.current.record("send(_:) was called but there is already a suspended action. Call 'resume()' before sending a new action.")
            return
        }

        coordinator.reset()

        await withCheckedContinuation { continuation in
            coordinator.dispatcherContinuation = continuation
            runner.enqueue { [weak self] in
                guard let coordinator = self?.coordinator else {
                    return
                }

                await EffectExecutor.$current.withValue(TestableEffectExecutor(coordinator: coordinator)) {
                    await self?.store.send(action)
                    coordinator.dispatcherContinuation.resumeOnce()
                }
            }
        }
    }

    /// Performs work on the store under test by mutating state and evaluating triggers.
    ///
    /// The state mutation and the trigger evaluation both run with the task-local values bound at the
    /// test store's creation, so state setters that read task-local values see those bindings.
    ///
    /// If another action is already suspended, this method records a test issue and returns.
    ///
    /// - Parameters:
    ///   - keyPath: The writable key path to mutate.
    ///   - value: The new value to assign.
    public func set<Value>(_ keyPath: WritableKeyPath<Store.State, Value>, to value: Value) async {
        guard coordinator.executorContinuation == nil else {
            IssueRecorder.current.record("set(_:to:) was called but there is already a suspended action. Call 'resume()' before sending a new action.")
            return
        }

        coordinator.reset()

        await withCheckedContinuation { continuation in
            coordinator.dispatcherContinuation = continuation
            runner.enqueue { [weak self] in
                guard let coordinator = self?.coordinator, let store = self?.store else {
                    return
                }

                let oldState = store.state
                store.state[keyPath: keyPath] = value

                await EffectExecutor.$current.withValue(TestableEffectExecutor(coordinator: coordinator)) {
                    await store.fireTriggers(from: oldState)
                    coordinator.dispatcherContinuation.resumeOnce()
                }
            }
        }
    }

    /// Resumes the next suspended action chain produced by effects or triggers.
    ///
    /// If there is no suspended action, this method records a test issue.
    public func resume() async {
        guard coordinator.executorContinuation != nil else {
            IssueRecorder.current.record("resume() was called but there are no suspended actions to resume.")
            return
        }
        await withCheckedContinuation { continuation in
            coordinator.dispatcherContinuation = continuation
            coordinator.executorContinuation.resumeOnce()
        }
    }

    /// Returns a property from the underlying store using dynamic member lookup.
    ///
    /// - Parameter keyPath: A key path to a property on the wrapped store.
    /// - Returns: The current value of the targeted property.
    public subscript<Value>(dynamicMember keyPath: KeyPath<Store, Value>) -> Value {
        store[keyPath: keyPath]
    }
}
