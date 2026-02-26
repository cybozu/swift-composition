import Composition
import Observation
import SwiftUI

@MainActor @Observable
final class TodoList: Composable {
    struct State {
        var todos: [TodoItem] = []
        var filter: Filter = .all
        var isLoading = false

        var activeCount: Int {
            todos.filter { !$0.isCompleted }.count
        }

        var filteredTodos: [TodoItem] {
            switch filter {
            case .all: todos
            case .active: todos.filter { !$0.isCompleted }
            case .completed: todos.filter { $0.isCompleted }
            }
        }

        enum Filter {
            case all
            case active
            case completed
        }
    }

    var state: State
    var input: TodoInput?
    let delegate: @MainActor (Action) async -> Void = { _ in }
    let repository: any TodoRepository

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.todoCountDidChange, observing: \.todos.count),
    ]

    init(state: State? = nil, input: TodoInput? = nil, repository: (any TodoRepository)? = nil) {
        self.state = state ?? State()
        self.input = input
        self.repository = repository ?? InMemoryTodoRepository()
    }

    func reduce(_ action: Action) async {
        switch action {
        case .task:
            state.isLoading = true
            let todos = await repository.fetchAll()
            await send(.todosLoaded(todos))

        case .todosLoaded(let todos):
            state.todos = todos
            state.isLoading = false

        case .newTodoButtonTapped:
            guard input == nil else { return }
            input = TodoInput(delegate: mapAction { .input($0) })

        case .todoItemButtonTapped(let id):
            guard let index = state.todos.firstIndex(where: { $0.id == id }) else {
                return
            }
            state.todos[index].isCompleted.toggle()
            await repository.save(state.todos)

        case .input(.addButtonTapped):
            guard let title = input?.state.normalizedTitle,
                  !title.isEmpty else {
                return
            }
            state.todos.append(TodoItem(title: title))
            input = nil
            await repository.save(state.todos)

        case .todoCountDidChange where state.filter == .completed:
            state.filter = .all

        case .todoCountDidChange:
            return
        }
    }

    enum Action {
        case task
        case todosLoaded([TodoItem])
        case newTodoButtonTapped
        case todoItemButtonTapped(UUID)
        case input(TodoInput.Action)
        case todoCountDidChange
    }
}

struct TodoListView: View {
    @State private var store = TodoList()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.filteredTodos) { item in
                        Button {
                            Task { await store.send(.todoItemButtonTapped(item.id)) }
                        } label: {
                            Label {
                                Text(item.title)
                                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                            } icon: {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isCompleted ? .green : .secondary)
                            }
                            .strikethrough(item.isCompleted)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(store.activeCount) remaining")
                }

                if let store = store.input {
                    Section {
                        TodoInputView(store: store)
                    }
                }
            }
            .overlay {
                if store.isLoading {
                    ProgressView()
                } else if store.filteredTodos.isEmpty && store.input == nil {
                    ContentUnavailableView {
                        Label("No Todos", systemImage: "checklist")
                    } description: {
                        switch store.filter {
                        case .all:
                            Text("Tap + to add your first todo.")
                        case .active:
                            Text("No active todos. Everything is done!")
                        case .completed:
                            Text("No completed todos yet.")
                        }
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if store.input == nil {
                    Button {
                        Task { await store.send(.newTodoButtonTapped) }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.accentColor, in: Circle())
                            .shadow(radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
            }
            .task { await store.send(.task) }
            .navigationTitle("Todos")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Filter", selection: $store.filter) {
                        Text("All").tag(TodoList.State.Filter.all)
                        Text("Active").tag(TodoList.State.Filter.active)
                        Text("Completed").tag(TodoList.State.Filter.completed)
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
}
