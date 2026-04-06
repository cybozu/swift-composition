# ``CompositionTesting``

@Metadata {
    @PageImage(
        purpose: icon,
        source: "logo-testing",
        alt: "An icon representing the CompositionTesting."
    )
    @PageColor(orange)
}

A companion testing module that provides ``TestStore`` for deterministic, step-by-step verification of state transitions, triggers, and re-entrant effects.

## Overview

``TestStore`` wraps any ``Composable`` store, suspending follow-up effects until you explicitly call `resume()`. This lets you verify each intermediate state one step at a time.

## Topics

### Testing

- ``TestStore``
