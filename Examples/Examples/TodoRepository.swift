protocol TodoRepository {
    func fetchAll() async -> [TodoItem]
    func save(_ todos: [TodoItem]) async
}

final actor InMemoryTodoRepository: TodoRepository {
    private var todos: [TodoItem] = []

    init() {}

    func fetchAll() -> [TodoItem] {
        todos
    }

    func save(_ todos: [TodoItem]) {
        self.todos = todos
    }
}
