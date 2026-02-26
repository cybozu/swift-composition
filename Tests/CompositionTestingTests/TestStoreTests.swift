import Composition
import CompositionTesting
import Observation
import Synchronization
import Testing

struct TestStoreTests {
    /// preconditions: a store with no triggers
    /// expectations: send applies the action to state without requiring resume
    @Test @MainActor
    func sendAppliesActionToStateWithoutRequiringResume() async {
        let store = TestStore { Child() }

        await store.send(.incrementButtonTapped)

        #expect(store.count == 1)
    }

    /// preconditions: a store with no triggers
    /// expectations: consecutive sends apply the action to state without requiring resume
    @Test @MainActor
    func consecutiveSendsApplyActionToStateWithoutRequiringResume() async {
        let store = TestStore { Child() }

        await store.send(.incrementButtonTapped)
        await store.send(.incrementButtonTapped)

        #expect(store.count == 2)
    }

    /// preconditions: a store with a trigger observing count
    /// expectations: consecutive send+resume cycles apply the original action and the trigger-fired action to state
    @Test @MainActor
    func consecutiveSendResumeCyclesApplyActionsToStateForTrigger() async {
        let store = TestStore { TriggerCounter() }

        await store.send(.incrementButtonTapped)
        await store.resume()

        #expect(store.count == 1)
        #expect(store.countDidChangeHandledCount == 1)

        await store.send(.incrementButtonTapped)
        await store.resume()

        #expect(store.count == 2)
        #expect(store.countDidChangeHandledCount == 2)
    }

    /// preconditions: a store with a trigger observing count
    /// expectations: send suspends before the trigger-fired action is executed; resume completes it
    @Test @MainActor
    func sendSuspendsBeforeTriggerFiredActionIsExecuted() async {
        let store = TestStore { TriggerCounter() }

        await store.send(.incrementButtonTapped)

        #expect(store.countDidChangeHandledCount == 0)

        await store.resume()

        #expect(store.countDidChangeHandledCount == 1)
    }

    /// preconditions: a store containing a child that delegates via action mapping
    /// expectations: scoped send suspends before the delegate-driven action is executed; resume completes it
    @Test @MainActor
    func scopedSendSuspendsBeforeDelegateDrivenActionIsExecuted() async {
        let store = TestStore { DelegateParent() }

        await store.scope(to: \.child).send(.incrementButtonTapped)

        #expect(store.childActionHandledCount == 0)

        await store.resume()

        #expect(store.childActionHandledCount == 1)
    }

    /// preconditions: a store with no triggers
    /// expectations: set applies the value to state without requiring resume
    @Test @MainActor
    func setAppliesValueToStateWithoutRequiringResume() async {
        let store = TestStore { Child() }

        await store.set(\.count, to: 5)

        #expect(store.count == 5)
    }

    /// preconditions: a store with a trigger observing count
    /// expectations: set applies the value and the trigger-fired action to state without requiring resume
    @Test @MainActor
    func setAppliesValueAndTriggerFiredActionToStateWithoutRequiringResume() async {
        let store = TestStore { TriggerCounter() }

        await store.set(\.count, to: 1)

        #expect(store.count == 1)
        #expect(store.countDidChangeHandledCount == 1)
    }

    /// preconditions: a store with a trigger observing count
    /// expectations: set does not apply the trigger-fired action to state when the observed value does not change
    @Test @MainActor
    func setDoesNotApplyTriggerFiredActionToStateWhenObservedValueDoesNotChange() async {
        let store = TestStore { TriggerCounter() }

        await store.set(\.count, to: 0)

        #expect(store.countDidChangeHandledCount == 0)
    }

    /// preconditions: a store with cascading triggers
    /// expectations: set suspends before the cascading trigger-fired action is executed; resume completes it
    @Test @MainActor
    func setSuspendsBeforeCascadingTriggerFiredActionIsExecuted() async {
        let store = TestStore { CascadingTriggerCounter() }

        await store.set(\.count, to: 5)

        #expect(store.doubledCount == 10)
        #expect(store.doubledCountDidChangeHandledCount == 0)

        await store.resume()

        #expect(store.doubledCount == 10)
        #expect(store.doubledCountDidChangeHandledCount == 1)
    }

    /// preconditions: a store with cascading triggers
    /// expectations: consecutive set+resume cycles apply the value and the trigger-fired actions to state
    @Test @MainActor
    func consecutiveSetResumeCyclesApplyValueAndActionsToStateForCascadingTriggers() async {
        let store = TestStore { CascadingTriggerCounter() }

        await store.set(\.count, to: 1)
        await store.resume()

        #expect(store.count == 1)
        #expect(store.doubledCount == 2)
        #expect(store.doubledCountDidChangeHandledCount == 1)

        await store.set(\.count, to: 2)
        await store.resume()

        #expect(store.count == 2)
        #expect(store.doubledCount == 4)
        #expect(store.doubledCountDidChangeHandledCount == 2)
    }

    /// preconditions: a store with nested-send actions
    /// expectations: send requires multiple resumes, each unblocking one nested-send action in order
    @Test @MainActor
    func sendRequiresMultipleResumesForNestedSends() async {
        let store = TestStore { ActionChain() }

        await store.send(.firstAction)
        #expect(store.log == [.firstStarted])

        await store.resume()
        #expect(store.log == [.firstStarted, .secondStarted])

        await store.resume()
        #expect(store.log == [.firstStarted, .secondStarted, .third, .secondCompleted, .firstCompleted])
    }

    /// preconditions: a store containing a child
    /// expectations: scoped send forwards the action to the child
    @Test @MainActor
    func scopedSendForwardsActionToChild() async {
        let store = TestStore { ChildParent(child: Child()) }

        await store.scope(to: \.child).send(.incrementButtonTapped)

        #expect(store.child.count == 1)
    }

    /// preconditions: a store containing a child
    /// expectations: scoped set forwards the value to the child
    @Test @MainActor
    func scopedSetForwardsValueToChild() async {
        let store = TestStore { ChildParent(child: Child()) }

        await store.scope(to: \.child).set(\.count, to: 42)

        #expect(store.child.count == 42)
    }

    /// preconditions: a store containing a nested child-grandchild hierarchy
    /// expectations: nested scoped send forwards the action to the grandchild
    @Test @MainActor
    func nestedScopedSendForwardsActionToGrandchild() async {
        let store = TestStore { ChildParent(child: ChildParent(child: Child())) }

        await store.scope(to: \.child).scope(to: \.child).send(.incrementButtonTapped)

        #expect(store.child.child.count == 1)
    }

    /// preconditions: a store containing a child with a trigger observing count
    /// expectations: scoped send suspends before the trigger-fired action is executed; resume completes it
    @Test @MainActor
    func scopedSendSuspendsBeforeTriggerFiredActionIsExecuted() async {
        let store = TestStore { ChildParent(child: TriggerCounter()) }

        await store.scope(to: \.child).send(.incrementButtonTapped)

        #expect(store.child.count == 1)
        #expect(store.child.countDidChangeHandledCount == 0)

        await store.resume()

        #expect(store.child.count == 1)
        #expect(store.child.countDidChangeHandledCount == 1)
    }

    /// preconditions: a store containing a child with cascading triggers
    /// expectations: scoped set suspends before the cascading trigger-fired action is executed; resume completes it
    @Test @MainActor
    func scopedSetSuspendsBeforeCascadingTriggerFiredActionIsExecuted() async {
        let store = TestStore { ChildParent(child: CascadingTriggerCounter()) }

        await store.scope(to: \.child).set(\.count, to: 5)

        #expect(store.child.doubledCount == 10)
        #expect(store.child.doubledCountDidChangeHandledCount == 0)

        await store.resume()

        #expect(store.child.doubledCount == 10)
        #expect(store.child.doubledCountDidChangeHandledCount == 1)
    }

    /// preconditions: a store containing a nil optional child
    /// expectations: optional scope returns nil when target is nil
    @Test @MainActor
    func optionalScopeReturnsNilWhenTargetIsNil() async {
        let store = TestStore { ChildParent<Child?>(child: nil) }

        #expect(store.scope(to: \.child) == nil)
    }

    /// preconditions: a store containing a non-nil optional child
    /// expectations: optional scoped send forwards the action to the child
    @Test @MainActor
    func optionalScopedSendForwardsActionToChild() async {
        let store = TestStore { ChildParent<Child?>(child: Child()) }

        await store.scope(to: \.child)?.send(.incrementButtonTapped)

        #expect(store.child?.count == 1)
    }

    /// preconditions: a store containing a non-nil optional child
    /// expectations: optional scoped set forwards the value to the child
    @Test @MainActor
    func optionalScopedSetForwardsValueToChild() async {
        let store = TestStore { ChildParent<Child?>(child: Child()) }

        await store.scope(to: \.child)?.set(\.count, to: 42)

        #expect(store.child?.count == 42)
    }

    /// preconditions: a store containing a nested non-nil optional child-grandchild hierarchy
    /// expectations: nested optional scoped send forwards the action to the grandchild
    @Test @MainActor
    func nestedOptionalScopedSendForwardsActionToGrandchild() async {
        let store = TestStore { ChildParent<ChildParent<Child?>?>(child: ChildParent<Child?>(child: Child())) }

        await store.scope(to: \.child)?.scope(to: \.child)?.send(.incrementButtonTapped)

        #expect(store.child?.child?.count == 1)
    }

    /// preconditions: a store containing a non-nil optional child with a trigger observing count
    /// expectations: optional scoped send suspends before the trigger-fired action is executed; resume completes it
    @Test @MainActor
    func optionalScopedSendSuspendsBeforeTriggerFiredActionIsExecuted() async {
        let store = TestStore { ChildParent<TriggerCounter?>(child: TriggerCounter()) }

        await store.scope(to: \.child)?.send(.incrementButtonTapped)

        #expect(store.child?.count == 1)
        #expect(store.child?.countDidChangeHandledCount == 0)

        await store.resume()

        #expect(store.child?.count == 1)
        #expect(store.child?.countDidChangeHandledCount == 1)
    }

    /// preconditions: a store containing a non-nil optional child with cascading triggers
    /// expectations: optional scoped set suspends before the cascading trigger-fired action is executed; resume completes it
    @Test @MainActor
    func optionalScopedSetSuspendsBeforeCascadingTriggerFiredActionIsExecuted() async {
        let store = TestStore { ChildParent<CascadingTriggerCounter?>(child: CascadingTriggerCounter()) }

        await store.scope(to: \.child)?.set(\.count, to: 5)

        #expect(store.child?.doubledCount == 10)
        #expect(store.child?.doubledCountDidChangeHandledCount == 0)

        await store.resume()

        #expect(store.child?.doubledCount == 10)
        #expect(store.child?.doubledCountDidChangeHandledCount == 1)
    }

    /// preconditions: a store with a trigger observing count
    /// expectations: subsequent send records an issue when a trigger-fired action is suspended; the action is not applied to state
    @Test @MainActor
    func subsequentSendRecordsIssueWhenTriggerFiredActionIsSuspended() async {
        let recordedMessages = Mutex<[String]>([])
        let store = TestStore { TriggerCounter() }

        await IssueRecorder.$current.withValue(TestIssueRecorder { message in
            recordedMessages.withLock { $0.append(message) }
        }) {
            await store.send(.incrementButtonTapped)
            let countSnapshot = store.count
            #expect(recordedMessages.withLock(\.self).isEmpty)

            await store.send(.incrementButtonTapped)
            #expect(store.count == countSnapshot)
            #expect(recordedMessages.withLock(\.self).count == 1)

            await store.resume()
            #expect(recordedMessages.withLock(\.self).count == 1)
        }
    }

    /// preconditions: a store with a trigger observing count
    /// expectations: subsequent set records an issue when a trigger-fired action is suspended; the value is not applied to state
    @Test @MainActor
    func subsequentSetRecordsIssueWhenTriggerFiredActionIsSuspended() async {
        let recordedMessages = Mutex<[String]>([])
        let store = TestStore { TriggerCounter() }

        await IssueRecorder.$current.withValue(TestIssueRecorder { message in
            recordedMessages.withLock { $0.append(message) }
        }) {
            await store.send(.incrementButtonTapped)
            let countSnapshot = store.count
            #expect(recordedMessages.withLock(\.self).isEmpty)

            await store.set(\.count, to: 2)
            #expect(store.count == countSnapshot)
            #expect(recordedMessages.withLock(\.self).count == 1)

            await store.resume()
            #expect(recordedMessages.withLock(\.self).count == 1)
        }
    }

    /// preconditions: a store with no triggers
    /// expectations: resume records an issue when no action is suspended
    @Test @MainActor
    func resumeRecordsIssueWhenNoActionIsSuspended() async {
        let recordedMessages = Mutex<[String]>([])
        let store = TestStore { Child() }

        await IssueRecorder.$current.withValue(TestIssueRecorder { message in
            recordedMessages.withLock { $0.append(message) }
        }) {
            await store.resume()
            #expect(recordedMessages.withLock(\.self).count == 1)
        }
    }

    /// preconditions: a store with a trigger observing count
    /// expectations: resume records an issue when the suspended action is already completed
    @Test @MainActor
    func resumeRecordsIssueWhenSuspendedActionIsAlreadyCompleted() async {
        let recordedMessages = Mutex<[String]>([])
        let store = TestStore { TriggerCounter() }

        await IssueRecorder.$current.withValue(TestIssueRecorder { message in
            recordedMessages.withLock { $0.append(message) }
        }) {
            await store.send(.incrementButtonTapped)
            await store.resume()
            #expect(recordedMessages.withLock(\.self).isEmpty)

            await store.resume()
            #expect(recordedMessages.withLock(\.self).count == 1)
        }
    }

    /// preconditions: a store with a trigger observing count
    /// expectations: store deallocation records an issue when a trigger-fired action is suspended
    @Test @MainActor
    func storeDeallocationRecordsIssueWhenTriggerFiredActionIsSuspended() async {
        let recordedMessages = Mutex<[String]>([])

        await IssueRecorder.$current.withValue(TestIssueRecorder { message in
            recordedMessages.withLock { $0.append(message) }
        }) {
            var store: TestStore<TriggerCounter, TriggerCounter>? = TestStore { TriggerCounter() }
            await store?.send(.incrementButtonTapped)
            store = nil
        }
        #expect(recordedMessages.withLock(\.self).count == 1)
    }

    /// preconditions: a store with no triggers
    /// expectations: store deallocation does not record an issue when no action is suspended
    @Test @MainActor
    func storeDeallocationDoesNotRecordIssueWhenNoActionIsSuspended() async {
        let recordedMessages = Mutex<[String]>([])

        await IssueRecorder.$current.withValue(TestIssueRecorder { message in
            recordedMessages.withLock { $0.append(message) }
        }) {
            let store = TestStore { Child() }
            await store.send(.incrementButtonTapped)
        }
        #expect(recordedMessages.withLock(\.self).isEmpty)
    }

    /// preconditions: a store containing a child that delegates via action mapping
    /// expectations: scoped send does not record an issue when a delegate-driven action is suspended
    @Test @MainActor
    func scopedSendDoesNotRecordIssueWhenDelegateDrivenActionIsSuspended() async {
        let recordedMessages = Mutex<[String]>([])

        await IssueRecorder.$current.withValue(TestIssueRecorder { message in
            recordedMessages.withLock { $0.append(message) }
        }) {
            let store = TestStore { DelegateParent() }
            await store.scope(to: \.child).send(.incrementButtonTapped)

            #expect(recordedMessages.withLock(\.self).isEmpty)
        }
    }

    /// preconditions: a store with cascading triggers
    /// expectations: send requires multiple resumes, each unblocking one trigger-fired action in order
    @Test @MainActor
    func sendRequiresMultipleResumesForCascadingTriggers() async {
        let store = TestStore { CascadingTriggerCounter() }

        await store.send(.increment)
        #expect(store.count == 1)
        #expect(store.doubledCount == 0)
        #expect(store.doubledCountDidChangeHandledCount == 0)

        await store.resume()
        #expect(store.count == 1)
        #expect(store.doubledCount == 2)
        #expect(store.doubledCountDidChangeHandledCount == 0)

        await store.resume()
        #expect(store.count == 1)
        #expect(store.doubledCount == 2)
        #expect(store.doubledCountDidChangeHandledCount == 1)
    }

    /// preconditions: a store with cascading triggers
    /// expectations: consecutive send+resume cycles apply the original action and the trigger-fired actions to state
    @Test @MainActor
    func consecutiveSendResumeCyclesApplyActionsToStateForCascadingTriggers() async {
        let store = TestStore { CascadingTriggerCounter() }

        await store.send(.increment)
        await store.resume()
        await store.resume()
        #expect(store.count == 1)
        #expect(store.doubledCount == 2)
        #expect(store.doubledCountDidChangeHandledCount == 1)

        await store.send(.increment)
        await store.resume()
        await store.resume()
        #expect(store.count == 2)
        #expect(store.doubledCount == 4)
        #expect(store.doubledCountDidChangeHandledCount == 2)
    }

    /// preconditions: a store with cascading triggers
    /// expectations: send requires multiple resumes, each unblocking one trigger-fired action or nested-send action in order
    @Test @MainActor
    func sendRequiresMultipleResumesForCascadingTriggersAndNestedSend() async {
        let store = TestStore { CascadingTriggerCounter() }

        await store.send(.incrementAndNotify)
        #expect(store.count == 1)
        #expect(store.doubledCount == 0)
        #expect(store.doubledCountDidChangeHandledCount == 0)
        #expect(store.notifiedHandledCount == 0)

        await store.resume()
        #expect(store.count == 1)
        #expect(store.doubledCount == 2)
        #expect(store.doubledCountDidChangeHandledCount == 0)
        #expect(store.notifiedHandledCount == 0)

        await store.resume()
        #expect(store.count == 1)
        #expect(store.doubledCount == 2)
        #expect(store.doubledCountDidChangeHandledCount == 1)
        #expect(store.notifiedHandledCount == 0)

        await store.resume()
        #expect(store.count == 1)
        #expect(store.doubledCount == 2)
        #expect(store.doubledCountDidChangeHandledCount == 1)
        #expect(store.notifiedHandledCount == 1)
    }

    /// preconditions: a store with cascading triggers
    /// expectations: consecutive send+resume cycles apply the original action, the trigger-fired actions, and the nested-send action to state
    @Test @MainActor
    func consecutiveSendResumeCyclesApplyActionsToStateForCascadingTriggersAndNestedSend() async {
        let store = TestStore { CascadingTriggerCounter() }

        await store.send(.incrementAndNotify)
        await store.resume()
        await store.resume()
        await store.resume()
        #expect(store.count == 1)
        #expect(store.doubledCount == 2)
        #expect(store.doubledCountDidChangeHandledCount == 1)
        #expect(store.notifiedHandledCount == 1)

        await store.send(.incrementAndNotify)
        await store.resume()
        await store.resume()
        await store.resume()
        #expect(store.count == 2)
        #expect(store.doubledCount == 4)
        #expect(store.doubledCountDidChangeHandledCount == 2)
        #expect(store.notifiedHandledCount == 2)
    }

    /// preconditions: a store with multi-property triggers
    /// expectations: send requires multiple resumes, each unblocking one trigger-fired action in order
    @Test @MainActor
    func sendRequiresMultipleResumesForMultiPropertyTriggers() async {
        let store = TestStore { MultiPropertyTriggerCounter() }

        await store.send(.updateBoth)

        #expect(store.countDidChangeHandledCount == 0)
        #expect(store.nameDidChangeHandledCount == 0)

        await store.resume()

        #expect(store.countDidChangeHandledCount == 1)
        #expect(store.nameDidChangeHandledCount == 0)

        await store.resume()

        #expect(store.countDidChangeHandledCount == 1)
        #expect(store.nameDidChangeHandledCount == 1)
    }

    /// preconditions: a store with multi-property triggers
    /// expectations: send requires multiple resumes, each unblocking one trigger-fired action or nested-send action in order
    @Test @MainActor
    func sendRequiresMultipleResumesForMultiPropertyTriggersAndNestedSend() async {
        let store = TestStore { MultiPropertyTriggerCounter() }

        await store.send(.updateBothAndNotify)
        #expect(store.countDidChangeHandledCount == 0)
        #expect(store.nameDidChangeHandledCount == 0)
        #expect(store.notifiedHandledCount == 0)

        await store.resume()
        #expect(store.countDidChangeHandledCount == 1)
        #expect(store.nameDidChangeHandledCount == 0)
        #expect(store.notifiedHandledCount == 0)

        await store.resume()
        #expect(store.countDidChangeHandledCount == 1)
        #expect(store.nameDidChangeHandledCount == 1)
        #expect(store.notifiedHandledCount == 0)

        await store.resume()
        #expect(store.countDidChangeHandledCount == 1)
        #expect(store.nameDidChangeHandledCount == 1)
        #expect(store.notifiedHandledCount == 1)
    }

    /// preconditions: a store with two triggers both observing count
    /// expectations: set suspends before the second trigger-fired action is executed; resume completes it
    @Test @MainActor
    func setSuspendsBeforeSecondTriggerFiredActionIsExecuted() async {
        let store = TestStore { DualTriggerCounter() }

        await store.set(\.count, to: 1)

        #expect(store.handler1CalledCount == 1)
        #expect(store.handler2CalledCount == 0)

        await store.resume()

        #expect(store.handler1CalledCount == 1)
        #expect(store.handler2CalledCount == 1)
    }
}

private struct TestIssueRecorder: IssueRecordable {
    private let handler: @Sendable (String) -> Void

    init(_ handler: @escaping @Sendable (String) -> Void) {
        self.handler = handler
    }

    func record(_ message: String) {
        handler(message)
    }
}

@MainActor @Observable
private final class Child: Composable {
    struct State {
        var count = 0
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void

    init(delegate: @escaping @MainActor (Action) async -> Void = { _ in }) {
        self.delegate = delegate
    }

    func reduce(_ action: Action) async {
        switch action {
        case .incrementButtonTapped:
            state.count += 1
        }
    }

    enum Action {
        case incrementButtonTapped
    }
}

@MainActor @Observable
private final class TriggerCounter: Composable {
    struct State {
        var count = 0
        var countDidChangeHandledCount = 0
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void = { _ in }

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countDidChange, observing: \.count),
    ]

    func reduce(_ action: Action) async {
        switch action {
        case .incrementButtonTapped:
            state.count += 1
        case .countDidChange:
            state.countDidChangeHandledCount += 1
        }
    }

    enum Action {
        case incrementButtonTapped
        case countDidChange
    }
}

@MainActor @Observable
private final class DelegateParent: Composable {
    struct State {
        var childActionHandledCount = 0
    }

    var state = State()
    @ObservationIgnored lazy var child = Child(delegate: mapAction { .child($0) })
    let delegate: @MainActor (Action) async -> Void = { _ in }

    func reduce(_ action: Action) async {
        switch action {
        case .child(.incrementButtonTapped):
            state.childActionHandledCount += 1
        }
    }

    enum Action {
        case child(Child.Action)
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
    let delegate: @MainActor (Action) async -> Void = { _ in }

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countDidChange, observing: \.count),
        trigger(.doubledCountDidChange, observing: \.doubledCount),
    ]

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
private final class ActionChain: Composable {
    struct State {
        var log: [Log] = []
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void = { _ in }

    func reduce(_ action: Action) async {
        switch action {
        case .firstAction:
            state.log.append(.firstStarted)
            await send(.secondAction)
            state.log.append(.firstCompleted)

        case .secondAction:
            state.log.append(.secondStarted)
            await send(.thirdAction)
            state.log.append(.secondCompleted)

        case .thirdAction:
            state.log.append(.third)
        }
    }

    enum Action {
        case firstAction
        case secondAction
        case thirdAction
    }

    enum Log {
        case firstStarted
        case firstCompleted
        case secondStarted
        case secondCompleted
        case third
    }
}

@MainActor @Observable
private final class ChildParent<ChildStore>: Composable {
    let child: ChildStore
    let delegate: @MainActor (Action) async -> Void = { _ in }

    init(child: ChildStore) {
        self.child = child
    }

    enum Action {
        case none
    }
}

@MainActor @Observable
private final class MultiPropertyTriggerCounter: Composable {
    struct State {
        var count = 0
        var name = ""
        var countDidChangeHandledCount = 0
        var nameDidChangeHandledCount = 0
        var notifiedHandledCount = 0
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void = { _ in }

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countDidChange, observing: \.count),
        trigger(.nameDidChange, observing: \.name),
    ]

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
            state.countDidChangeHandledCount += 1
        case .nameDidChange:
            state.nameDidChangeHandledCount += 1
        }
    }

    enum Action {
        case updateBoth
        case updateBothAndNotify
        case notified
        case countDidChange
        case nameDidChange
    }
}

@MainActor @Observable
private final class DualTriggerCounter: Composable {
    struct State {
        var count = 0
        var handler1CalledCount = 0
        var handler2CalledCount = 0
    }

    var state = State()
    let delegate: @MainActor (Action) async -> Void = { _ in }

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countDidChange1, observing: \.count),
        trigger(.countDidChange2, observing: \.count),
    ]

    func reduce(_ action: Action) async {
        switch action {
        case .countDidChange1:
            state.handler1CalledCount += 1
        case .countDidChange2:
            state.handler2CalledCount += 1
        }
    }

    enum Action {
        case countDidChange1
        case countDidChange2
    }
}
