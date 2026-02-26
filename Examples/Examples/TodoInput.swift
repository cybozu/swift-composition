import Composition
import Observation
import SwiftUI

@MainActor @Observable
final class TodoInput: Composable {
    struct State {
        var title = ""

        var normalizedTitle: String {
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var state: State
    let delegate: @MainActor (Action) async -> Void

    init(state: State? = nil, delegate: @escaping @MainActor (Action) async -> Void) {
        self.state = state ?? State()
        self.delegate = delegate
    }

    enum Action {
        case addButtonTapped
    }
}

struct TodoInputView: View {
    @Bindable var store: TodoInput

    var body: some View {
        HStack {
            TextField("What needs to be done?", text: $store.title)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task { await store.send(.addButtonTapped) }
                }

            Button("Add") {
                Task { await store.send(.addButtonTapped) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.normalizedTitle.isEmpty)
        }
    }
}
