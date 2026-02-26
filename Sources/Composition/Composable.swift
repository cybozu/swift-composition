/// A type that manages state transitions and side effects in response to actions.
@MainActor @dynamicMemberLookup
public protocol Composable: AnyObject {
    /// The state managed by this composable type. Defaults to `Void` when no state is needed.
    associatedtype State = Void

    /// The action type that drives state transitions.
    associatedtype Action

    /// The current state.
    var state: State { get set }

    /// Triggers evaluated after each state transition.
    var triggers: [Trigger<State, Action>] { get }

    /// A callback invoked after `reduce(_:)` completes for a sent action.
    var delegate: @MainActor (Action) async -> Void { get }

    /// Handles an action by mutating state and starting side effects.
    ///
    /// - Parameter action: The action to reduce.
    func reduce(_ action: Action) async
}

public extension Composable {
    /// Handles an action by performing no work in the default implementation.
    ///
    /// - Parameter action: The action to reduce.
    func reduce(_ action: Action) async {}

    /// Triggers evaluated after each state transition. Returns an empty array by default.
    var triggers: [Trigger<State, Action>] { [] }

    /// Sends an action to this composable.
    ///
    /// This method executes work in the following order:
    /// 1. Pending triggers from prior state changes
    /// 2. ``reduce(_:)``
    /// 3. ``delegate``
    /// 4. Triggers from the current state change
    ///
    /// - Parameter action: The action to send.
    func send(_ action: Action) async {
        await EffectExecutor.current.perform { [weak self] in
            guard let self else { return }

            let oldState = state

            await exhaustTriggers(since: oldState) {
                await reduce($0.action)
                await delegate($0.action)
                await EffectExecutor.current.yield()
            }

            await reduce(action)
            await delegate(action)

            await exhaustTriggers(since: oldState) {
                await EffectExecutor.current.yield()
                await reduce($0.action)
                await delegate($0.action)
            }
        }
    }

    /// Creates an async sender for child actions by transforming them into this composable's actions.
    ///
    /// - Parameter transform: A closure that maps child actions into parent actions.
    /// - Returns: An async function that sends transformed actions through `send(_:)`.
    func mapAction<ChildAction>(
        _ transform: @escaping @Sendable (ChildAction) -> Action
    ) -> (@MainActor @Sendable (ChildAction) async -> Void) {
        { [weak self] childAction in
            await self?.send(transform(childAction))
        }
    }

    /// Creates a trigger that sends an action whenever an observed value changes.
    ///
    /// - Parameters:
    ///   - action: The action to send when the observed value changes.
    ///   - observe: A closure that extracts an equatable value from `State`.
    /// - Returns: A trigger that fires when `observe` yields a different value.
    func trigger<Value: Equatable>(
        _ action: Action,
        observing observe: @escaping (State) -> Value
    ) -> Trigger<State, Action> {
        var lastValue: Value?
        return Trigger(action: action) { oldState, newState in
            let oldValue = lastValue ?? observe(oldState)
            let newValue = observe(newState)
            lastValue = newValue
            return oldValue != newValue
        }
    }

    /// Reads a property on `state` using dynamic member lookup.
    ///
    /// - Parameter keyPath: A key path to a property on `State`.
    /// - Returns: The value at `keyPath`.
    subscript<T>(dynamicMember keyPath: KeyPath<State, T>) -> T {
        state[keyPath: keyPath]
    }

    /// Reads or writes a property on `state` using dynamic member lookup.
    ///
    /// When setting a value, this subscript compares the previous and current states and evaluates triggers.
    ///
    /// - Parameter keyPath: A writable key path to a property on `State`.
    /// - Returns: The value at `keyPath`.
    subscript<T>(dynamicMember keyPath: WritableKeyPath<State, T>) -> T {
        get {
            state[keyPath: keyPath]
        }
        set {
            let oldState = state
            state[keyPath: keyPath] = newValue
            Task.immediate { [weak self] in
                await self?.fireTriggers(from: oldState)
            }
        }
    }

    package func fireTriggers(from oldState: State) async {
        await exhaustTriggers(since: oldState) {
            await send($0.action)
        }
    }

    private func exhaustTriggers(
        since initialState: State,
        perform body: @MainActor (Trigger<State, Action>) async -> Void
    ) async {
        var oldState = initialState
        var pendingTriggers = triggersToFire(from: oldState)

        while !pendingTriggers.isEmpty {
            oldState = state
            for trigger in pendingTriggers {
                await body(trigger)
            }
            pendingTriggers = triggersToFire(from: oldState)
        }
    }

    private func triggersToFire(from oldState: State) -> [Trigger<State, Action>] {
        triggers.filter { $0.shouldFire(oldState, state) }
    }
}

public extension Composable where State == Void {
    /// The current state. Returns `Void` by default.
    var state: Void {
        get { () }
        set {}
    }
}
