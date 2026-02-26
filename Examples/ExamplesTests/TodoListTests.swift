import Composition
import CompositionTesting
import Foundation
import Testing

@testable import Examples

struct TodoListTests {
    /// preconditions: an incomplete todo exists
    /// expectations: tapping the todo marks it as completed
    @Test @MainActor
    func tappingIncompleteTodoMarksItAsCompleted() async {
        let todoID = UUID()
        let store = TestStore {
            TodoList(state: .init(todos: [.init(id: todoID, title: "Task 1", isCompleted: false)]))
        }

        await store.send(.todoItemButtonTapped(todoID))

        #expect(store.todos.map(\.isCompleted) == [true])
    }

    /// preconditions: a completed todo exists
    /// expectations: tapping the todo marks it as incomplete
    @Test @MainActor
    func tappingCompletedTodoMarksItAsIncomplete() async {
        let todoID = UUID()
        let store = TestStore {
            TodoList(state: .init(todos: [.init(id: todoID, title: "Task 1", isCompleted: true)]))
        }

        await store.send(.todoItemButtonTapped(todoID))

        #expect(store.todos.map(\.isCompleted) == [false])
    }

    /// preconditions: an incomplete todo exists in storage
    /// expectations: tapping the todo persists the completion change to storage
    @Test @MainActor
    func tappingIncompleteTodoPersistsIt() async {
        let todoID = UUID()
        let repository = MockTodoRepository(todos: [
            TodoItem(id: todoID, title: "Task 1", isCompleted: false),
        ])
        let store = TestStore {
            TodoList(
                state: .init(todos: repository.todos),
                repository: repository
            )
        }

        await store.send(.todoItemButtonTapped(todoID))

        #expect(repository.todos.map(\.isCompleted) == [true])
    }

    /// preconditions: a todo exists
    /// expectations: tapping a non-existent todo ID does not change state
    @Test @MainActor
    func tappingNonExistentTodoIsNoOp() async {
        let store = TestStore {
            TodoList(state: .init(todos: [.init(title: "Task 1")]))
        }

        await store.send(.todoItemButtonTapped(UUID()))

        #expect(store.todos.map(\.title) == ["Task 1"])
        #expect(store.todos.map(\.isCompleted) == [false])
    }

    /// preconditions: the input form is not displayed
    /// expectations: tapping the new-todo button shows the input form
    @Test @MainActor
    func tappingNewTodoButtonShowsInputForm() async {
        let store = TestStore { TodoList() }

        #expect(store.input == nil)

        await store.send(.newTodoButtonTapped)

        #expect(store.input != nil)
    }

    /// preconditions: the input form is displayed with a non-blank title
    /// expectations: submitting adds the todo to the list and closes the input form
    @Test @MainActor
    func submittingNonBlankTitleAddsTodo() async {
        let store = TestStore { TodoList() }

        await store.send(.newTodoButtonTapped)

        await store.scope(to: \.input)?.set(\.title, to: "Task 1")
        await store.scope(to: \.input)?.send(.addButtonTapped)

        // Resume the re-entrant `.input(.addButtonTapped)` dispatched via mapAction delegate
        await store.resume()

        #expect(store.input == nil)
        #expect(store.todos.map(\.title) == ["Task 1"])

        // Resume the `.todoCountDidChange` trigger fired by todos.count changing
        await store.resume()
    }

    /// preconditions: the input form is displayed with a whitespace-only title
    /// expectations: submitting does not add a todo to the list and does not close the input form
    @Test @MainActor
    func submittingWhitespaceOnlyTitleDoesNotAddTodo() async {
        let store = TestStore { TodoList() }

        await store.send(.newTodoButtonTapped)

        await store.scope(to: \.input)?.set(\.title, to: "   ")
        await store.scope(to: \.input)?.send(.addButtonTapped)

        // Resume the re-entrant `.input(.addButtonTapped)` dispatched via mapAction delegate
        await store.resume()

        #expect(store.todos.isEmpty)
        #expect(store.input != nil)
    }

    /// preconditions: the input form is displayed with a whitespace-padded title
    /// expectations: submitting trims the title, adds the todo to the list, and closes the input form
    @Test @MainActor
    func submittingWhitespacePaddedTitleTrimsAndAddsTodo() async {
        let store = TestStore { TodoList() }

        await store.send(.newTodoButtonTapped)

        await store.scope(to: \.input)?.set(\.title, to: "  Task 1  ")
        await store.scope(to: \.input)?.send(.addButtonTapped)

        // Resume the re-entrant `.input(.addButtonTapped)` dispatched via mapAction delegate
        await store.resume()

        #expect(store.input == nil)
        #expect(store.todos.map(\.title) == ["Task 1"])

        // Resume the `.todoCountDidChange` trigger fired by todos.count changing
        await store.resume()
    }

    /// preconditions: the filter is set to "completed"
    /// expectations: adding a todo resets the filter to "all"
    @Test @MainActor
    func addingTodoWhileFilteredByCompletedResetsFilterToAll() async {
        let store = TestStore { TodoList(state: .init(filter: .completed)) }

        await store.send(.newTodoButtonTapped)

        await store.scope(to: \.input)?.set(\.title, to: "Task 1")
        await store.scope(to: \.input)?.send(.addButtonTapped)

        // Resume the re-entrant `.input(.addButtonTapped)` dispatched via mapAction delegate
        await store.resume()

        #expect(store.input == nil)
        #expect(store.todos.map(\.title) == ["Task 1"])

        // Resume the `.todoCountDidChange` trigger fired by todos.count changing
        await store.resume()

        #expect(store.filter == .all)
    }

    /// preconditions: the filter is set to "active"
    /// expectations: adding a todo does not reset the filter
    @Test @MainActor
    func addingTodoWhileFilteredByActiveDoesNotResetFilter() async {
        let store = TestStore { TodoList(state: .init(filter: .active)) }

        await store.send(.newTodoButtonTapped)

        await store.scope(to: \.input)?.set(\.title, to: "Task 1")
        await store.scope(to: \.input)?.send(.addButtonTapped)

        // Resume the re-entrant `.input(.addButtonTapped)` dispatched via mapAction delegate
        await store.resume()

        #expect(store.input == nil)
        #expect(store.todos.map(\.title) == ["Task 1"])

        // Resume the `.todoCountDidChange` trigger fired by todos.count changing
        await store.resume()

        #expect(store.filter == .active)
    }

    /// preconditions: two incomplete todos exist
    /// expectations: tapping an incomplete todo decrements the active count by one
    @Test @MainActor
    func tappingIncompleteTodoDecrementsActiveCount() async {
        let todoID = UUID()
        let store = TestStore {
            TodoList(state: .init(todos: [
                .init(id: todoID, title: "Task 1", isCompleted: false),
                .init(id: UUID(), title: "Task 2", isCompleted: false),
            ]))
        }

        #expect(store.activeCount == 2)

        await store.send(.todoItemButtonTapped(todoID))

        #expect(store.activeCount == 1)
    }

    /// preconditions: todos exist in storage
    /// expectations: displaying the list loads saved todos from storage
    @Test @MainActor
    func displayingListLoadsSavedTodos() async {
        let repository = MockTodoRepository(todos: [
            TodoItem(title: "Task 1"),
            TodoItem(title: "Task 2"),
        ])
        let store = TestStore { TodoList(repository: repository) }

        await store.send(.task)

        #expect(store.isLoading == true)

        // Resume the nested `send(.todosLoaded)` dispatched inside the `.task` handler
        await store.resume()

        #expect(store.isLoading == false)
        #expect(store.todos.map(\.title) == ["Task 1", "Task 2"])

        // Resume the `.todoCountDidChange` trigger fired by todos.count changing
        await store.resume()
    }

    /// preconditions: no todos exist in storage
    /// expectations: adding a todo persists it to storage
    @Test @MainActor
    func addingTodoPersistsIt() async {
        let repository = MockTodoRepository()
        let store = TestStore { TodoList(repository: repository) }

        await store.send(.newTodoButtonTapped)
        await store.scope(to: \.input)?.set(\.title, to: "Task 1")
        await store.scope(to: \.input)?.send(.addButtonTapped)

        // Resume the re-entrant `.input(.addButtonTapped)` dispatched via mapAction delegate
        await store.resume()

        #expect(repository.todos.map(\.title) == ["Task 1"])

        // Resume the `.todoCountDidChange` trigger fired by todos.count changing
        await store.resume()
    }

    /// preconditions: the filter is set to "all" and both completed and incomplete todos exist
    /// expectations: filteredTodos returns all todos
    @Test @MainActor
    func filteredTodosReturnsAllTodosWhenFilterIsAll() async {
        let store = TestStore {
            TodoList(state: .init(
                todos: [
                    .init(title: "Active", isCompleted: false),
                    .init(title: "Done", isCompleted: true),
                ],
                filter: .all
            ))
        }

        #expect(store.filteredTodos.map(\.title) == ["Active", "Done"])
    }

    /// preconditions: the filter is set to "active" and both completed and incomplete todos exist
    /// expectations: filteredTodos returns only active todos
    @Test @MainActor
    func filteredTodosReturnsOnlyActiveTodosWhenFilterIsActive() async {
        let store = TestStore {
            TodoList(state: .init(
                todos: [
                    .init(title: "Active", isCompleted: false),
                    .init(title: "Done", isCompleted: true),
                ],
                filter: .active
            ))
        }

        #expect(store.filteredTodos.map(\.title) == ["Active"])
    }

    /// preconditions: the filter is set to "completed" and both completed and incomplete todos exist
    /// expectations: filteredTodos returns only completed todos
    @Test @MainActor
    func filteredTodosReturnsOnlyCompletedTodosWhenFilterIsCompleted() async {
        let store = TestStore {
            TodoList(state: .init(
                todos: [
                    .init(title: "Active", isCompleted: false),
                    .init(title: "Done", isCompleted: true),
                ],
                filter: .completed
            ))
        }

        #expect(store.filteredTodos.map(\.title) == ["Done"])
    }

    /// preconditions: the input form is displayed
    /// expectations: tapping the new-todo button does not change the input form
    @Test @MainActor
    func tappingNewTodoButtonWhileInputIsOpenIsNoOp() async {
        let store = TestStore { TodoList() }

        await store.send(.newTodoButtonTapped)
        let inputBefore = store.input

        await store.send(.newTodoButtonTapped)

        #expect(store.input === inputBefore)
    }
}

@MainActor
private final class MockTodoRepository: TodoRepository {
    var todos: [TodoItem]

    init(todos: [TodoItem] = []) {
        self.todos = todos
    }

    func fetchAll() async -> [TodoItem] {
        todos
    }

    func save(_ todos: [TodoItem]) async {
        self.todos = todos
    }
}
