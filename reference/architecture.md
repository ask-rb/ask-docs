---
layout: default
title: Architecture & Ownership
parent: Reference
nav_order: 4
---

# Architecture & Ownership

How the ask-rb gems are layered, and the rule for **who owns a constant**.

## Layering

Gems depend downward — a gem can only use what a gem *below* it provides:

```
ask-schema            JSON Schema DSL           (zero deps)
   ↑
ask-core              Value objects + contracts (zero deps)
   ↑                              ↑
ask-tools             Tool framework            (depends on ask-core, ask-schema)
   ↑                              ↑
ask-tools-shell       Shell/FS/code tools       (depends on ask-tools, ask-sandbox-providers)
ask-agent             Agent loop                (depends on ask-core, ask-tools, ask-llm-providers, ...)

ask-llm-providers     All 33 LLM providers      (depends on ask-core, ask-auth)
ask-rag / ask-graph   RAG & workflow            (depend on ask-core)
ask-state-providers   State backends            (depends on ask-core)
```

The leaves that *don't* need tooling — `ask-llm-providers`, `ask-rag`,
`ask-graph`, `ask-state-providers` — depend only on `ask-core`, so they never
pull in the tool framework or the schema DSL. That is why `ask-core` is kept
tiny and zero-dependency rather than folded into a bigger gem.

## The ownership rule

**Shared value objects and base contracts live in `ask-core`. Feature gems
depend on `ask-core` and extend what it provides — they never redefine it.**

Concretely, `ask-core` owns:

| Constant | Purpose |
|---|---|
| `Ask::Message`, `Ask::Conversation` | Message model and role normalization |
| `Ask::Content` (`Text`/`Image`/`Audio`/`Video`/`File`) | Multi-modal content blocks |
| `Ask::Stream`, `Ask::Chunk` | Streaming primitives |
| `Ask::Provider` | Provider base contract |
| `Ask::Result` | Standardized return value (foundational **and** tool API) |
| `Ask::ModelCatalog`, `Ask::ModelInfo` | Model registry and metadata |
| `Ask::ToolDef` | Immutable tool definition |
| `Ask::Document` | Text + metadata value object |
| `Ask::Error` hierarchy | Structured error types |

Feature gems *extend* these — `ask-tools` adds `Ask::Tool` and the
`Ask::Tools` registry, `ask-tools-shell` adds `Ask::Tools::Bash` and friends,
`ask-llm-providers` adds `Ask::Providers::*`. They never open a class owned by
ask-core and replace its methods.

## Why this rule exists

Two gems once both defined `Ask::Result` — ask-core with
`success`/`failure`/`aborted`/`blocked`, ask-tools with `ok`/`error`. Each
worked in isolation, but in any app loading both (every ask-agent app) the
second one to load clobbered the first's constructor, so `Ask::Result.success`
raised `ArgumentError: missing keyword: :ok`, and `ask-rag`'s
`raw.output` call failed on provider embedding results.

The fix was to make `Ask::Result` a single class in `ask-core` supporting both
APIs, and have `ask-tools` depend on ask-core instead of redefining it:

```ruby
Ask::Result.success("Data processed")        # foundational API
Ask::Result.ok(data: "Data processed")       # tool API — same class
```

## When you add a shared constant

If a value object, base class, or contract will be used by more than one gem:

1. Put it in `ask-core` (zero dependencies, frozen, tested there).
2. Require it from ask-core; feature gems `require "ask"` and extend it.
3. Never define the same constant in a feature gem — depend on ask-core
   instead (ask-core is zero-dependency, so this never creates a cycle).
4. If a feature gem currently *redefines* a constant, that's a bug: move the
   canonical definition into ask-core and make the feature gem extend it.
