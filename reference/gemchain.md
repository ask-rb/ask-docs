---
layout: default
title: Gemchain
parent: Reference
nav_order: 5
---

# Gemchain

If you maintain multiple Ruby gems that depend on each other — like the ask-rb ecosystem — you know the pain. You update one gem, then you have to figure out which other gems need new releases, bump their version constraints, run their tests, and release them one by one, in the right order.

Gemchain automates this. It maps the dependency graph between your gems, warns you before a release that will break dependents, and can cascade an update through the entire chain — bumping, testing, and releasing each gem in the correct order.

**Use gemchain when** you maintain a family of gems with interdependencies and want to release updates safely without breaking anything downstream.

## Installation

```sh
gem install gemchain
```

## Setting up

Gemchain reads a `cascade.yml` file that describes your gem ecosystem. It lives at the root of your workspace (the directory containing all your gem subdirectories):

```yaml
# cascade.yml
workspace: .
include: ask-*
```

Or list gems explicitly:

```yaml
# cascade.yml
workspace: .
gems:
  ask-core: ./ask-core
  ask-agent: ./ask-agent
  ask-tools: ./ask-tools
```

The `include` pattern scans for directories matching the glob. Each directory must contain a `.gemspec` file.

## Checking your ecosystem

Run `gemchain check` to see the full picture:

```sh
gemchain check
```

This shows every gem, its version, its dependencies, and how many other gems depend on it. It's the quickest way to understand your gem graph at a glance.

## Guarding a release

Before releasing a gem, run `gemchain guard` to see what will break:

```sh
gemchain guard ask-core
```

```
⚠  Pre-release Guard: ask-core v0.7.0

  7 gem(s) directly depend on ask-core:
    • ask-llm-providers (0.10.0) — requires: ask-core >= 0.1
    • ask-state-providers (0.3.0) — requires: ask-core >= 0.1
    ...

  Before releasing ask-core, make sure these gems still work:
    ⬜ ask-llm-providers (0.10.0)
    ⬜ ask-state-providers (0.3.0)
    ...
```

This is a safety net. It won't let you release blindly — it forces you to acknowledge the downstream impact.

## Cascading an update

When you're ready to release, `gemchain update` does the whole thing:

```sh
gemchain update ask-core 0.8.0 --dry-run    # see the plan, change nothing
gemchain update ask-core 0.8.0 --test-only  # run dependents' tests, no releases
gemchain update ask-core 0.8.0              # execute the full cascade
gemchain update ask-core 0.8.0 --yes        # skip confirmations
```

What happens:

1. **Bump** the source gem to the new version
2. **Update** every dependent gem's version constraint to include the new version
3. **Test** each dependent gem's test suite
4. **Release** each dependent gem in dependency order

If any step fails, the cascade stops. You see exactly where it broke, what was released so far, and what's left.

## Linking for local development

When developing across multiple gems, you need local path references in each gem's Gemfile. Gemchain generates them:

```sh
gemchain link
```

This outputs the `Gemfile` block that points each gem to its local directory, so you can test changes across gems without publishing.

## How it fits with ask-rb

The ask-rb ecosystem has 40+ gems. When `ask-core` changes, a dozen downstream gems might need updates. Without gemchain, that's a manual, error-prone process. With it, a single command handles the entire cascade — correctly, every time.

## Next steps

- [Gem Index](/ask-docs/reference/gems) — all ask-rb gems
- [Architecture & Ownership](/ask-docs/reference/architecture) — gem layering
- [gemchain on GitHub](https://github.com/ask-rb/gemchain)
