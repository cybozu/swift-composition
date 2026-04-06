<picture>
  <source srcset="https://github.com/user-attachments/assets/40da1089-3b78-4f37-977d-de16856f52fa" height="70" media="(prefers-color-scheme: dark)" alt="LicenseList by Cybozu">
  <img src="https://github.com/user-attachments/assets/6fa80241-16bb-494a-9870-86fea13df69f" height="70" alt="LicenseList by Cybozu">
</picture>

![Swift 6.3](https://img.shields.io/badge/Swift-6.3-F05138.svg?style=flat&logo=swift)
![Platforms](https://img.shields.io/badge/Platforms-iOS_26_|_macOS_26_|_watchOS_26_|_tvOS_26_|_visionOS_26-blue.svg)
![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)

## What is Composition?

Composition is a lightweight Swift framework for building composable app architecture. It provides a protocol-based system for managing state transitions, side effects, and parent-child composition using `async`/`await`.

The framework is intentionally minimal: no macros, no code generation, and zero external dependencies. The entire core fits in a handful of files. It builds on Swift's native concurrency (`async`/`await`, `@MainActor`, `@TaskLocal`) and the Observation framework (`@Observable`).

Composition ships with **CompositionTesting**, a companion module that provides `TestStore` for deterministic, step-by-step verification of state transitions, triggers, and re-entrant effects.

## Features

**Composition**
- Protocol-based architecture with the `Composable` protocol
- Parent-child composition via `mapAction(_:)` delegate forwarding
- `@dynamicMemberLookup` for natural property access on stores

**Reactivity**
- Struct-based state with value semantics
- Enum-driven actions for exhaustive state transitions
- Reactive `Trigger` system that fires actions on state changes
- Native SwiftUI and Observation framework integration

**Deterministic Testing**
- `TestStore` for step-by-step verification — send, set, resume, scope

## Example

The following examples demonstrate the core concepts using a simple counter. A full Todo app is available in the [Examples](Examples/) directory.

### Defining a Store

A store conforms to the `Composable` protocol, declaring its `State`, `Action`, and `reduce(_:)` method:

```swift
import Composition
import Observation

@MainActor @Observable
final class Counter: Composable {
    struct State {
        var count = 0
    }

    enum Action {
        case incrementButtonTapped
        case decrementButtonTapped
    }

    var state: State
    let delegate: @MainActor (Action) async -> Void

    init(state: State = State(), delegate: @escaping @MainActor (Action) async -> Void = { _ in }) {
        self.state = state
        self.delegate = delegate
    }

    func reduce(_ action: Action) async {
        switch action {
        case .incrementButtonTapped:
            state.count += 1
        case .decrementButtonTapped:
            state.count -= 1
        }
    }
}
```

### Composing Parent and Child

Use `mapAction(_:)` to connect a child store's actions to a parent:

```swift
@MainActor @Observable
final class Parent: Composable {
    enum Action {
        case child(Child.Action)
    }

    var state = ()
    let delegate: @MainActor (Action) async -> Void = { _ in }
    lazy var child = Child(delegate: mapAction { .child($0) })

    func reduce(_ action: Action) async {
        switch action {
        case .child:
            // Handle child actions at the parent level if needed
            return
        }
    }
}
```

### Reactive Triggers

Triggers automatically dispatch actions when observed state values change:

```swift
@MainActor @Observable
final class Counter: Composable {
    struct State {
        var count = 0
        var isEven = true
    }

    enum Action {
        case incrementButtonTapped
        case countDidChange
    }

    var state: State

    @ObservationIgnored lazy var triggers: [Trigger<State, Action>] = [
        trigger(.countDidChange, observing: \.count),
    ]

    // ...

    func reduce(_ action: Action) async {
        switch action {
        case .incrementButtonTapped:
            state.count += 1
        case .countDidChange:
            state.isEven = state.count.isMultiple(of: 2)
        }
    }
}
```

### SwiftUI Integration

Stores integrate naturally with SwiftUI using `@State` and `@Bindable`:

```swift
import SwiftUI

struct CounterView: View {
    @State private var store = Counter()

    var body: some View {
        VStack {
            // Dynamic member lookup: store.count instead of store.state.count
            Text("Count: \(store.count)")

            HStack {
                Button("-") {
                    Task { await store.send(.decrementButtonTapped) }
                }
                Button("+") {
                    Task { await store.send(.incrementButtonTapped) }
                }
            }
        }
    }
}
```

For two-way bindings, use `@Bindable`:

```swift
struct TodoInputView: View {
    @Bindable var store: TodoInput

    var body: some View {
        TextField("Title", text: $store.title)
    }
}
```

### Testing

`TestStore` from **CompositionTesting** provides deterministic control over state transitions:

```swift
import CompositionTesting
import Testing

struct CounterTests {
    @Test @MainActor
    func increment() async {
        let store = TestStore { Counter() }

        await store.send(.incrementButtonTapped)

        // Dynamic member lookup works on TestStore too
        #expect(store.count == 1)
    }
}
```

When actions produce re-entrant effects or trigger cascading actions, use `resume()` to step through each one:

```swift
@Test @MainActor
func addingTodoFiresTrigger() async {
    let store = TestStore { TodoList() }

    await store.send(.newTodoButtonTapped)

    // Use scope(to:) to interact with child stores
    await store.scope(to: \.input)?.set(\.title, to: "Buy milk")
    await store.scope(to: \.input)?.send(.addButtonTapped)

    // Resume the re-entrant action dispatched via mapAction delegate
    await store.resume()

    #expect(store.todos.map(\.title) == ["Buy milk"])

    // Resume the trigger fired by todos.count changing
    await store.resume()
}
```

## Requirements

|  | Minimum Version |
|---|---|
| Swift | 6.3 |
| Xcode | 26.0 |
| iOS | 26.0 |
| macOS | 26.0 |
| watchOS | 26.0 |
| tvOS | 26.0 |
| visionOS | 26.0 |

## Installation

### Swift Package Manager

Add the package dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/swift-composition.git", from: "0.1.0"),
]
```

Then add the products to your targets:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "Composition", package: "swift-composition"),
    ]
),
.testTarget(
    name: "YourAppTests",
    dependencies: [
        .product(name: "CompositionTesting", package: "swift-composition"),
    ]
),
```

Or in Xcode, go to **File > Add Package Dependencies** and paste the repository URL.

## Documentation

For a complete working example, see the [Todo app](Examples/) in the Examples directory.

## License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.
