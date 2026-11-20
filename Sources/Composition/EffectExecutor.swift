package protocol EffectExecutable: Sendable {
    nonisolated(nonsending) func perform(_ effect: @MainActor @escaping () async -> Void) async
    nonisolated(nonsending) func yield() async
}

package enum EffectExecutor {
    @TaskLocal package static var current: any EffectExecutable = DefaultEffectExecutor()
}

private struct DefaultEffectExecutor: EffectExecutable {
    func perform(_ effect: @MainActor @escaping () async -> Void) async {
        await effect()
    }

    func yield() async {}
}
