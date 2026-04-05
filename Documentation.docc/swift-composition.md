# swift-composition

@Metadata {
    @TechnologyRoot
    @PageImage(
        purpose: icon,
        source: "logo",
        alt: "An icon representing swift-composition."
    )
    @PageColor(orange)
}

A lightweight Swift framework for building composable app architecture.

## Overview

The framework is intentionally minimal: no macros, no code generation, and zero external dependencies. The entire core fits in a handful of files. It builds on Swift's native concurrency (`async`/`await`, `@MainActor`, `@TaskLocal`) and the Observation framework (`@Observable`).

## Additional Resources

- [GitHub Repository](https://github.com/cybozu/swift-composition)

## Topics

### Frameworks

- ``Composition``
- ``CompositionTesting``
