import Testing

@testable import CompositionTesting

struct ContinuationSlotTests {
    /// preconditions: a slot holding a continuation whose task holds a new continuation in the same slot as soon as it resumes
    /// expectations: resume keeps the newly held continuation in the slot
    @Test
    func resumeKeepsContinuationHeldDuringResumption() {
        let slot = ContinuationSlot()
        Task(executorPreference: ImmediateTaskExecutor()) {
            await withCheckedContinuation { slot.hold($0) }
            await withCheckedContinuation { slot.hold($0) }
        }
        #expect(slot.isEmpty == false)

        slot.resume()

        #expect(slot.isEmpty == false)

        slot.resume()
    }
}

private final class ImmediateTaskExecutor: TaskExecutor {
    func enqueue(_ job: consuming ExecutorJob) {
        job.runSynchronously(on: asUnownedTaskExecutor())
    }
}
