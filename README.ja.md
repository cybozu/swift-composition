<picture>
  <source srcset="https://github.com/user-attachments/assets/40da1089-3b78-4f37-977d-de16856f52fa" height="70" media="(prefers-color-scheme: dark)" alt="LicenseList by Cybozu">
  <img src="https://github.com/user-attachments/assets/6fa80241-16bb-494a-9870-86fea13df69f" height="70" alt="LicenseList by Cybozu">
</picture>

![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138.svg?style=flat&logo=swift)
![Platforms](https://img.shields.io/badge/Platforms-iOS_26_|_macOS_26_|_watchOS_26_|_tvOS_26_|_visionOS_26-blue.svg)
![SPM Compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)
![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)

## Composition とは？

Composition は、コンポーザブルなアプリアーキテクチャを構築するための軽量な Swift フレームワークです。`async`/`await` を活用し、プロトコルベースのシステムで状態遷移、副作用、親子コンポジションを管理します。

このフレームワークはマクロなし、コード生成なし、外部依存ゼロになるよう意図的に最小設計にしています。コア全体がわずか数ファイルに収まります。Swift のネイティブな並行処理（`async`/`await`、`@MainActor`、`@TaskLocal`）と Observation フレームワーク（`@Observable`）の上に構築されています。

Composition には **CompositionTesting** というモジュールが付属しており、`TestStore` を使用して状態遷移、トリガー、再入エフェクトの決定論的なステップバイステップにてテストが実装可能です。

## 機能

**Composition**
- `Composable` プロトコルによるプロトコルベースのアーキテクチャ
- `mapAction(_:)` によるデリゲート転送を使った親子コンポジション
- `@dynamicMemberLookup` によるストアのプロパティへの自然なアクセス

**リアクティビティ**
- 値セマンティクスを持つ構造体ベースの状態
- 網羅的な状態遷移のための列挙型駆動のアクション
- 状態変化に応じてアクションを発火するリアクティブな `Trigger` システム
- SwiftUI および Observation フレームワークとのネイティブな統合

**決定論的テスト**
- `TestStore` によるステップバイステップのテスト — send、set、resume、scope

## 使用例

以下の例では、シンプルなカウンターを使ってコアコンセプトを説明します。完全な Todo アプリは [Examples](Examples/) ディレクトリで確認できます。

### Store の定義

Store は `Composable` プロトコルに準拠し、`State`、`Action`、`reduce(_:)` メソッドを宣言します：

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

### 親と子のコンポジション

`mapAction(_:)` を使って子ストアのアクションを親に接続します：

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
            // 必要に応じて親レベルで子のアクションを処理
            return
        }
    }
}
```

### リアクティブトリガー

トリガーは、監視対象の状態値が変化したときに自動的にアクションをディスパッチします：

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

### SwiftUI との統合

Store は `@State` と `@Bindable` を使って SwiftUI と自然に統合できます：

```swift
import SwiftUI

struct CounterView: View {
    @State private var store = Counter()

    var body: some View {
        VStack {
            // Dynamic member lookup: store.state.count の代わりに store.count でアクセス
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

双方向バインディングには `@Bindable` を使用します：

```swift
struct TodoInputView: View {
    @Bindable var store: TodoInput

    var body: some View {
        TextField("Title", text: $store.title)
    }
}
```

### テスト

**CompositionTesting** の `TestStore` は、状態遷移の決定論的な制御を提供します：

```swift
import CompositionTesting
import Testing

struct CounterTests {
    @Test @MainActor
    func increment() async {
        let store = TestStore { Counter() }

        await store.send(.incrementButtonTapped)

        // Dynamic member lookup は TestStore でも使用可能
        #expect(store.count == 1)
    }
}
```

アクションが再入エフェクトやカスケードアクションを生成する場合、`resume()` を使って1つずつステップ実行できます：

```swift
@Test @MainActor
func addingTodoFiresTrigger() async {
    let store = TestStore { TodoList() }

    await store.send(.newTodoButtonTapped)

    // scope(to:) を使って子ストアとやり取り
    await store.scope(to: \.input)?.set(\.title, to: "Buy milk")
    await store.scope(to: \.input)?.send(.addButtonTapped)

    // mapAction デリゲート経由でディスパッチされた再入アクションを resume
    await store.resume()

    #expect(store.todos.map(\.title) == ["Buy milk"])

    // todos.count の変化によって発火されたトリガーを resume
    await store.resume()
}
```

`TestStore` は生成時に束縛されていたタスクローカル値を捕捉し、`send`、`set`、`resume` で処理されるすべてのアクション（再入する `send` やトリガーのカスケードを含む）と `set` による状態の書き換えは、その値の下で実行されます。そのためタスクローカル値は、テストダブルを注入する自然な継ぎ目になります。ストアの生成箇所で一度束縛すれば、`send` や `set` ごとに包む必要はありません：

```swift
enum FetchTodos {
    @TaskLocal static var current: () async -> [Todo] = { [] }
}

@Test @MainActor
func fetchesTodos() async {
    let store = FetchTodos.$current.withValue({ [Todo(title: "Buy milk")] }) {
        TestStore { TodoList() }
    }

    // この send は withValue のスコープ外だが、ストア生成時に束縛された値が見える
    // 個々の send を包んだタスクローカル値はアクションの実行には伝播しない
    await store.send(.refreshButtonTapped)
}
```

## 動作要件

|  | 最小バージョン |
|---|---|
| Swift | 6.2 |
| Xcode | 26.0 |
| iOS | 26.0 |
| macOS | 26.0 |
| watchOS | 26.0 |
| tvOS | 26.0 |
| visionOS | 26.0 |

## インストール

### Swift Package Manager

`Package.swift` にパッケージ依存関係を追加します：

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/swift-composition.git", from: "0.1.0"),
]
```

次に、ターゲットにプロダクトを追加します：

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

または、Xcode で **File > Add Package Dependencies** からリポジトリ URL を貼り付けてください。

## ドキュメント

詳細については、[API ドキュメント](https://cybozu.github.io/swift-composition/documentation/)を参照してください。

完全な動作例については、Examples ディレクトリの [Todo アプリ](Examples/)を参照してください。

## プライバシーマニフェスト

このライブラリはユーザー情報の収集や追跡を行わないため、PrivacyInfo.xcprivacy ファイルは含まれていません。

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。詳細は [LICENSE](LICENSE) を参照してください。
