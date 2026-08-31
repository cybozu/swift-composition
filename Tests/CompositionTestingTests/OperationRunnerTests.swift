import Testing

@testable import CompositionTesting

struct OperationRunnerTests {
    /// preconditions: an operation runner whose enqueued operation has completed
    /// expectations: runner deallocates after the last reference is released
    @Test @MainActor
    func runnerDeallocatesAfterLastReferenceIsReleased() async {
        var runner: OperationRunner? = OperationRunner()
        weak let weakRunner = runner

        await withCheckedContinuation { continuation in
            runner?.enqueue { continuation.resume() }
        }

        runner = nil

        #expect(weakRunner == nil)
    }

    /// preconditions: an operation runner whose enqueued operation is suspended
    /// expectations: runner deallocates while the enqueued operation is suspended
    @Test @MainActor
    func runnerDeallocatesWhileEnqueuedOperationIsSuspended() async {
        var runner: OperationRunner? = OperationRunner()
        weak let weakRunner = runner

        let operationContinuation = await withCheckedContinuation { started in
            runner?.enqueue {
                await withCheckedContinuation { continuation in
                    started.resume(returning: continuation)
                }
            }
        }

        runner = nil

        #expect(weakRunner == nil)

        operationContinuation.resume()
    }
}
