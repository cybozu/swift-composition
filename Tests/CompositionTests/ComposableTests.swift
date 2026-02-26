import Observation
import Synchronization
import Testing

@testable import Composition

struct ComposableTests {
    /// preconditions: a counter
    /// expectations: send applies the action to state
    @Test @MainActor
    func sendAppliesActionToState() async {
        let counter = Counter()

        await counter.send(.increment)

        #expect(counter.count == 1)
    }

    /// preconditions: a counter with a delegate
    /// expectations: send delivers the action to the delegate
    @Test @MainActor
    func sendDeliversActionToDelegate() async {
        var delegatedActions: [Counter.Action] = []
        let counter = Counter(delegate: { delegatedActions.append($0) })

        await counter.send(.increment)

        #expect(delegatedActions == [.increment])
    }

    /// preconditions: a counter with a delegate and a reduce callback
    /// expectations: send executes reduce before the delegate
    @Test @MainActor
    func sendExecutesReduceBeforeDelegate() async {
        var order: [String] = []
        let counter = Counter(
            onReduce: { order.append("reduce") },
            delegate: { _ in order.append("delegate") }
        )

        await counter.send(.increment)

        #expect(order == ["reduce", "delegate"])
    }

    /// preconditions: a counter, under a custom EffectExecutor
    /// expectations: send dispatches through the custom EffectExecutor
    @Test @MainActor
    func sendDispatchesThroughCustomEffectExecutor() async {
        let executorCalled = Mutex(false)
        let mockExecutor = MockEffectExecutor { effect in
            executorCalled.withLock { $0 = true }
            await effect()
        }

        let counter = Counter()
        await EffectExecutor.$current.withValue(mockExecutor) {
            await counter.send(.increment)
        }

        #expect(executorCalled.withLock(\.self) == true)
    }

    /// preconditions: a counter
    /// expectations: send does not prevent deallocation
    @Test @MainActor
    func sendDoesNotPreventDeallocation() async {
        var counter: Counter? = Counter()
        weak let weakCounter = counter

        await counter?.send(.increment)
        counter = nil

        #expect(weakCounter == nil)
    }

    /// preconditions: a counter with a trigger observing count parity, under a custom EffectExecutor
    /// expectations: set dispatches through the custom EffectExecutor
    @Test @MainActor
    func setDispatchesThroughCustomEffectExecutor() async {
        let executorCalled = Mutex(false)
        let mockExecutor = MockEffectExecutor { effect in
            executorCalled.withLock { $0 = true }
            await effect()
        }

        var continuation: CheckedContinuation<Void, Never>?
        let counter = TriggerCounter(delegate: { _ in
            continuation?.resume()
            continuation = nil
        })

        await EffectExecutor.$current.withValue(mockExecutor) {
            await withCheckedContinuation {
                continuation = $0
                counter.count = 1
            }
        }

        #expect(executorCalled.withLock(\.self) == true)
    }

    /// preconditions: a counter
    /// expectations: set does not prevent deallocation
    @Test @MainActor
    func setDoesNotPreventDeallocation() async {
        var counter: Counter? = Counter()
        weak let weakCounter = counter

        counter?.count = 1
        counter = nil

        #expect(weakCounter == nil)
    }

    /// preconditions: a parent containing a child that delegates via action mapping
    /// expectations: mapAction delivers the child action to the delegate
    @Test @MainActor
    func mapActionDeliversChildActionToDelegate() async {
        var delegatedActions: [Parent.Action] = []
        let parent = Parent(delegate: { delegatedActions.append($0) })
        let childDelegate = parent.mapAction { childAction in
            Parent.Action.child(childAction)
        }

        await childDelegate(.doSomething)

        #expect(delegatedActions == [.child(.doSomething)])
    }

    /// preconditions: a parent containing a child that delegates via action mapping
    /// expectations: mapAction does not prevent deallocation
    @Test @MainActor
    func mapActionDoesNotPreventDeallocation() async {
        var parent: Parent? = Parent(delegate: { _ in })
        weak let weakParent = parent
        let childDelegate = parent!.mapAction { childAction in
            Parent.Action.child(childAction)
        }
        _ = childDelegate

        parent = nil

        #expect(weakParent == nil)
    }

    /// preconditions: a parent containing a child that delegates via action mapping
    /// expectations: mapAction does not deliver the child action to the delegate after parent deallocation
    @Test @MainActor
    func mapActionDoesNotDeliverChildActionToDelegateAfterParentDeallocation() async {
        var delegateCallCount = 0
        var parent: Parent? = Parent(delegate: { _ in delegateCallCount += 1 })
        let childDelegate = parent!.mapAction { childAction in
            Parent.Action.child(childAction)
        }

        parent = nil
        await childDelegate(.doSomething)

        #expect(delegateCallCount == 0)
    }

    /// preconditions: a counter with a trigger observing count parity
    /// expectations: trigger fires on send when the observed value changes
    @Test @MainActor
    func triggerFiresOnSendWhenObservedValueChanges() async {
        var delegatedActions: [TriggerCounter.Action] = []
        let counter = TriggerCounter(delegate: { delegatedActions.append($0) })

        await counter.send(.increment)

        #expect(delegatedActions == [.increment, .countDidChange])
    }

    /// preconditions: a counter with a trigger observing count parity
    /// expectations: trigger does not fire on send when the observed value does not change
    @Test @MainActor
    func triggerDoesNotFireOnSendWhenObservedValueDoesNotChange() async {
        var delegatedActions: [TriggerCounter.Action] = []
        let counter = TriggerCounter(delegate: { delegatedActions.append($0) })

        await counter.send(.incrementByTwo)

        #expect(delegatedActions == [.incrementByTwo])
    }

    /// preconditions: a counter with a trigger observing count parity
    /// expectations: trigger fires on set when the observed value changes
    @Test @MainActor
    func triggerFiresOnSetWhenObservedValueChanges() async {
        var delegatedActions: [TriggerCounter.Action] = []
        var continuation: CheckedContinuation<Void, Never>?
        let counter = TriggerCounter(delegate: {
            delegatedActions.append($0)
            continuation?.resume()
            continuation = nil
        })

        await withCheckedContinuation {
            continuation = $0
            counter.count = 1
        }

        #expect(delegatedActions == [.countDidChange])
    }

    /// preconditions: a counter with a trigger observing count parity
    /// expectations: trigger does not fire on set when the observed value does not change
    @Test @MainActor
    func triggerDoesNotFireOnSetWhenObservedValueDoesNotChange() async throws {
        var delegatedActions: [TriggerCounter.Action] = []
        let counter = TriggerCounter(delegate: {
            delegatedActions.append($0)
        })

        counter.count = 2
        try await Task.sleep(for: .seconds(0.1))

        #expect(delegatedActions.isEmpty)
    }

    /// preconditions: a counter with a clearable trigger observing count
    /// expectations: trigger does not fire on send when triggers are cleared
    @Test @MainActor
    func triggerDoesNotFireOnSendWhenTriggersAreCleared() async {
        var observeCallCount = 0
        let counter = ClearableTriggerCounter()
        counter.onObserve = {
            observeCallCount += 1
        }

        await counter.send(.increment)

        let callCountSnapshot = observeCallCount

        counter.clearTriggers()
        await counter.send(.increment)

        #expect(observeCallCount == callCountSnapshot)
    }

    /// preconditions: a counter with a clearable trigger observing count
    /// expectations: trigger does not fire on set when triggers are cleared
    @Test @MainActor
    func triggerDoesNotFireOnSetWhenTriggersAreCleared() async throws {
        var observeCallCount = 0
        let counter = ClearableTriggerCounter()
        counter.onObserve = {
            observeCallCount += 1
        }

        await withCheckedContinuation { continuation in
            counter.onObserve = {
                if observeCallCount == 0 {
                    continuation.resume()
                }
                observeCallCount += 1
            }
            counter.count = 1
        }

        let callCountSnapshot = observeCallCount

        counter.clearTriggers()
        try await Task.sleep(for: .seconds(0.1))

        counter.count = 2
        try await Task.sleep(for: .seconds(0.1))

        #expect(observeCallCount == callCountSnapshot)
    }

    /// preconditions: a counter with a trigger observing count parity
    /// expectations: trigger does not prevent deallocation
    @Test @MainActor
    func triggerDoesNotPreventDeallocation() async {
        var counter: TriggerCounter? = TriggerCounter()
        weak let weakCounter = counter
        _ = counter?.triggers

        counter = nil

        #expect(weakCounter == nil)
    }

    /// preconditions: a counter with a trigger observing a combined value derived from count and name
    /// expectations: trigger fires on set when the combined observed value changes
    @Test @MainActor
    func triggerFiresOnSetWhenCombinedObservedValueChanges() async {
        var delegatedActions: [CombinedStateTriggerCounter.Action] = []
        var continuation: CheckedContinuation<Void, Never>?
        let counter = CombinedStateTriggerCounter(delegate: {
            delegatedActions.append($0)
            continuation?.resume()
            continuation = nil
        })

        await withCheckedContinuation {
            continuation = $0
            counter.name = "first"
        }
        await withCheckedContinuation {
            continuation = $0
            counter.count = 1
        }

        #expect(delegatedActions == [.stateDidChange, .stateDidChange])
    }

    /// preconditions: a counter with multiple triggers observing count and count parity
    /// expectations: multiple triggers fire on set in declaration order when the observed values change
    @Test @MainActor
    func multipleTriggersFireOnSetInDeclarationOrderWhenObservedValuesChange() async {
        var delegatedActions: [MultiTriggerCounter.Action] = []
        var expectedCount = 2
        var continuation: CheckedContinuation<Void, Never>?
        let counter = MultiTriggerCounter(delegate: {
            delegatedActions.append($0)
            expectedCount -= 1
            if expectedCount == 0 {
                continuation?.resume()
                continuation = nil
            }
        })

        await withCheckedContinuation {
            continuation = $0
            counter.count = 1
        }

        #expect(delegatedActions == [.countIncremented, .countBecameOdd])
    }

    /// preconditions: a counter with cascading triggers
    /// expectations: send delivers the original action, then the trigger-fired actions to the delegate
    @Test @MainActor
    func cascadingTriggersSendDeliversActionsToDelegate() async {
        var delegatedActions: [CascadingTriggerCounter.Action] = []
        let counter = CascadingTriggerCounter(delegate: { delegatedActions.append($0) })

        await counter.send(.increment)

        #expect(delegatedActions == [.increment, .countDidChange, .doubledCountDidChange])
    }

    /// preconditions: a counter with cascading triggers
    /// expectations: send applies the original action and the trigger-fired actions to state
    @Test @MainActor
    func cascadingTriggersSendAppliesActionsToState() async {
        let counter = CascadingTriggerCounter()

        await counter.send(.increment)

        #expect(counter.count == 1)
        #expect(counter.doubledCount == 2)
        #expect(counter.doubledCountDidChangeHandledCount == 1)
    }

    /// preconditions: a counter with cascading triggers
    /// expectations: nested send delivers the trigger-fired actions, then the nested-send action, then the original action to the delegate
    @Test @MainActor
    func cascadingTriggersNestedSendDeliversActionsToDelegate() async {
        var delegatedActions: [CascadingTriggerCounter.Action] = []
        let counter = CascadingTriggerCounter(delegate: { delegatedActions.append($0) })

        await counter.send(.incrementAndNotify)

        #expect(delegatedActions == [
            .countDidChange,
            .doubledCountDidChange,
            .notified,
            .incrementAndNotify,
        ])
    }

    /// preconditions: a counter with cascading triggers
    /// expectations: nested send applies the original action, the trigger-fired actions, and the nested-send action to state
    @Test @MainActor
    func cascadingTriggersNestedSendAppliesActionsToState() async {
        let counter = CascadingTriggerCounter()

        await counter.send(.incrementAndNotify)

        #expect(counter.count == 1)
        #expect(counter.doubledCount == 2)
        #expect(counter.doubledCountDidChangeHandledCount == 1)
        #expect(counter.notifiedHandledCount == 1)
    }

    /// preconditions: a counter with multi-property triggers
    /// expectations: send delivers the original action, then the trigger-fired actions to the delegate
    @Test @MainActor
    func multiPropertyTriggersSendDeliversActionsToDelegate() async {
        var delegatedActions: [MultiPropertyTriggerCounter.Action] = []
        let counter = MultiPropertyTriggerCounter(delegate: { delegatedActions.append($0) })

        await counter.send(.updateBoth)

        #expect(delegatedActions == [.updateBoth, .countDidChange, .nameDidChange])
    }

    /// preconditions: a counter with multi-property triggers
    /// expectations: send applies the original action and the trigger-fired actions to state
    @Test @MainActor
    func multiPropertyTriggersSendAppliesActionsToState() async {
        let counter = MultiPropertyTriggerCounter()

        await counter.send(.updateBoth)

        #expect(counter.count == 1)
        #expect(counter.name == "updated")
        #expect(counter.countChangedHandledCount == 1)
        #expect(counter.nameChangedHandledCount == 1)
    }

    /// preconditions: a counter with multi-property triggers
    /// expectations: nested send delivers the trigger-fired actions, then the nested-send action, then the original action to the delegate
    @Test @MainActor
    func multiPropertyTriggersNestedSendDeliversActionsToDelegate() async {
        var delegatedActions: [MultiPropertyTriggerCounter.Action] = []
        let counter = MultiPropertyTriggerCounter(delegate: { delegatedActions.append($0) })

        await counter.send(.updateBothAndNotify)

        #expect(delegatedActions == [
            .countDidChange,
            .nameDidChange,
            .notified,
            .updateBothAndNotify,
        ])
    }

    /// preconditions: a counter with multi-property triggers
    /// expectations: nested send applies the original action, the trigger-fired actions, and the nested-send action to state
    @Test @MainActor
    func multiPropertyTriggersNestedSendAppliesActionsToState() async {
        let counter = MultiPropertyTriggerCounter()

        await counter.send(.updateBothAndNotify)

        #expect(counter.count == 1)
        #expect(counter.name == "updated")
        #expect(counter.countChangedHandledCount == 1)
        #expect(counter.nameChangedHandledCount == 1)
        #expect(counter.notifiedHandledCount == 1)
    }

}

private struct MockEffectExecutor: EffectExecutable {
    let handler: @Sendable (@MainActor @escaping () async -> Void) async -> Void

    func perform(_ effect: @MainActor @escaping () async -> Void) async {
        await handler(effect)
    }

    func yield() async {}
}

@MainActor @Observable
private final class Counter: Composable {
    struct State {
        var count = 0
    }

    var state = State()
    let onReduce: (() -> Void)?
    let delegate: @MainActor (Action) async -> Void

    init(
        onReduce: (() -> Void)? = nil,
        delegate: @escaping @MainActor (Action) async -> Void = { _ in }
    ) {
        self.onReduce = onReduce
        self.delegate = delegate
    }

    func reduce(_ action: Action) async {
        onReduce?()
        switch action {
        case .increment:
            state.count += 1
        }
    }

    enum Action: Sendable {
        case increment
    }
}

@MainActor @Observable
private final class TriggerCounter: Composable {
    struct State {
        var count = 0
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countDidChange, observing: { $0.count % 2 })
    ]

    init(delegate: @escaping @MainActor (Action) async -> Void = { _ in }) {
        self.delegate = delegate
    }

    func reduce(_ action: Action) async {
        switch action {
        case .increment:
            state.count += 1
        case .incrementByTwo:
            state.count += 2
        case .countDidChange:
            return
        }
    }

    enum Action: Sendable, Equatable {
        case increment
        case incrementByTwo
        case countDidChange
    }
}

@MainActor @Observable
private final class Parent: Composable {
    let delegate: @MainActor (Action) async -> Void

    init(delegate: @escaping @MainActor (Action) async -> Void) {
        self.delegate = delegate
    }

    enum Action: Sendable, Equatable {
        case child(Child.Action)
    }
}

@MainActor @Observable
private final class Child: Composable {
    let delegate: @MainActor (Action) async -> Void

    init(delegate: @escaping @MainActor (Action) async -> Void) {
        self.delegate = delegate
    }

    enum Action: Sendable {
        case doSomething
    }
}

@MainActor @Observable
private final class ClearableTriggerCounter: Composable {
    struct State {
        var count = 0
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void = { _ in }
    var onObserve: (() -> Void)?

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countDidChange, observing: { [weak self] state in
            self?.onObserve?()
            return state.count
        })
    ]

    func clearTriggers() {
        triggers = []
    }

    func reduce(_ action: Action) async {
        switch action {
        case .increment:
            state.count += 1
        case .countDidChange:
            return
        }
    }

    enum Action: Sendable, Equatable {
        case increment
        case countDidChange
    }
}

@MainActor @Observable
private final class CombinedStateTriggerCounter: Composable {
    struct State {
        var count = 0
        var name = ""
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.stateDidChange, observing: { "\($0.count)-\($0.name)" })
    ]

    init(delegate: @escaping @MainActor (Action) async -> Void) {
        self.delegate = delegate
    }

    enum Action: Sendable, Equatable {
        case stateDidChange
    }
}

@MainActor @Observable
private final class MultiTriggerCounter: Composable {
    struct State {
        var count = 0
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countIncremented, observing: \.count),
        trigger(.countBecameOdd, observing: { $0.count % 2 })
    ]

    init(delegate: @escaping @MainActor (Action) async -> Void) {
        self.delegate = delegate
    }

    enum Action: Sendable, Equatable {
        case countIncremented
        case countBecameOdd
    }
}

@MainActor @Observable
private final class CascadingTriggerCounter: Composable {
    struct State {
        var count = 0
        var doubledCount = 0
        var doubledCountDidChangeHandledCount = 0
        var notifiedHandledCount = 0
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countDidChange, observing: \.count),
        trigger(.doubledCountDidChange, observing: \.doubledCount),
    ]

    init(delegate: @escaping @MainActor (Action) async -> Void = { _ in }) {
        self.delegate = delegate
    }

    func reduce(_ action: Action) async {
        switch action {
        case .increment:
            state.count += 1
        case .incrementAndNotify:
            state.count += 1
            await send(.notified)
        case .notified:
            state.notifiedHandledCount += 1
        case .countDidChange:
            state.doubledCount = state.count * 2
        case .doubledCountDidChange:
            state.doubledCountDidChangeHandledCount += 1
        }
    }

    enum Action {
        case increment
        case incrementAndNotify
        case notified
        case countDidChange
        case doubledCountDidChange
    }
}

@MainActor @Observable
private final class MultiPropertyTriggerCounter: Composable {
    struct State {
        var count = 0
        var name = ""
        var countChangedHandledCount = 0
        var nameChangedHandledCount = 0
        var notifiedHandledCount = 0
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countDidChange, observing: \.count),
        trigger(.nameDidChange, observing: \.name),
    ]

    init(delegate: @escaping @MainActor (Action) async -> Void = { _ in }) {
        self.delegate = delegate
    }

    func reduce(_ action: Action) async {
        switch action {
        case .updateBoth:
            state.count += 1
            state.name = "updated"
        case .updateBothAndNotify:
            state.count += 1
            state.name = "updated"
            await send(.notified)
        case .notified:
            state.notifiedHandledCount += 1
        case .countDidChange:
            state.countChangedHandledCount += 1
        case .nameDidChange:
            state.nameChangedHandledCount += 1
        }
    }

    enum Action: Sendable, Equatable {
        case updateBoth
        case updateBothAndNotify
        case notified
        case countDidChange
        case nameDidChange
    }
}
