@MainActor
final class OperationRunner {
    typealias Operation = @MainActor @Sendable () async -> Void

    private let continuation: AsyncStream<Operation>.Continuation

    init() {
        let (stream, continuation) = AsyncStream<Operation>.makeStream()
        self.continuation = continuation
        Task {
            for await operation in stream {
                await operation()
            }
        }
    }

    func enqueue(_ operation: @escaping Operation) {
        continuation.yield(operation)
    }

    deinit {
        continuation.finish()
    }
}
