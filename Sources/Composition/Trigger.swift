/// A state-change trigger that can send an action when its condition becomes true.
///
/// `Trigger` values are typically created with `Composable.trigger(_:observing:)`.
@MainActor
public struct Trigger<State, Action> {
    let action: Action
    let shouldFire: (State, State) -> Bool

    init(action: Action, when shouldFire: @escaping (State, State) -> Bool) {
        self.action = action
        self.shouldFire = shouldFire
    }
}
