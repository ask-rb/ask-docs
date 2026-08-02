---
layout: default
title: Custom Skills
parent: Extending
nav_order: 5
---

# Custom Skills

Create skill files that teach your agent methodology. Skills are markdown files with frontmatter — no Ruby code needed.

Skills are discovered by `ask-skills`, which `ask-agent` pulls in automatically. If you're running agents, your skills are picked up with zero setup. For standalone discovery (no agent loop), add the gem:

```ruby
gem "ask-skills"
```

## What Makes a Good Skill

A skill is most valuable when it teaches the agent *how* to approach a domain-specific problem:

- **Project conventions** — code style, testing patterns, commit format
- **Debugging workflows** — how to investigate specific types of issues
- **Domain knowledge** — business logic, regulations, terminology
- **Process documentation** — deployment steps, review checklists

## Quick Start

Create `agents/shared/skills/debugging/SKILL.md` in your project:

```markdown
---
name: debugging
description: Systematic debugging approach
---

When asked to debug a problem:

1. **Reproduce first** — confirm the issue exists
2. **Check the logs** — look for error messages and stack traces
3. **Isolate** — narrow down to the failing component
4. **Fix** — apply the minimal change that resolves it
5. **Verify** — confirm the fix works and doesn't break tests
```

That's it. The agent will discover this skill and list it in the system prompt automatically.

## Skill Frontmatter

```yaml
---
name: rails-deployment          # Required. Used by the agent to identify the skill
description: >-                 # Required. Shown in the agent's system prompt
  Rails deployment process and rollback procedure
tags:                           # Optional. For organization
  - rails
  - deployment
  - production
version: 1                      # Optional. Integer
author: Your Name               # Optional
always: true                    # Optional. Load full instructions into every session's system prompt
---
```

`always: true` is the one that changes behavior: the skill's full instructions are injected into every session's system prompt instead of being listed for the LLM to load on demand. Use it sparingly — always-on skills eat context. Any other frontmatter keys land in `skill.metadata` for your own tooling.

## Writing Effective Skills

### Do

```markdown
## Code Review Checklist

1. **Read the diff** — understand what changed and why
2. **Check for nil** — are there potential NoMethodError paths?
3. **Verify tests** — does the change include tests? Do they pass the edge cases?
4. **Review for SQL injection** — are there raw SQL queries with interpolation?
5. **Check mass assignment** — are there unprotected attributes?
```

Talk directly to the LLM. Use numbered steps. Reference tool names.

### Don't

```markdown
## Code Review

When doing a code review, it's important to check various things. You might want to look at the diff first, and then maybe check for tests, among other things. Additionally, you should consider security issues.
```

Vague, passive, and doesn't leverage the LLM's ability to follow structured instructions.

## Skill Organization

```
agents/shared/skills/
├── debugging/
│   └── SKILL.md              # General debugging
├── rails-conventions/
│   └── SKILL.md              # Rails project patterns
├── database-migrations/
│   ├── SKILL.md              # Migration best practices
│   └── references/
│       └── migration-guide.md  # Bundled reference docs
└── code-review/
    ├── SKILL.md              # PR review checklist
    └── scripts/
        └── check-diff.sh     # Bundled scripts
```

Directories named after the skill, each with a `SKILL.md` inside. `references/`, `scripts/`, and `assets/` subdirectories are bundled as sibling files — the skill object exposes them as `skill.references`, `skill.scripts`, and `skill.assets`.

## Auto-Discovery

Skills are auto-discovered from, in priority order:

| Location | Priority | Purpose |
|---|---|---|
| Per-agent `agents/<name>/skills/` | Highest | Skills for one agent only |
| Shared project `agents/shared/skills/` | High | Project-specific methodology |
| User `~/.config/ask/skills/` | Medium | Personal methodology |
| Gems (`ask/skills/*/SKILL.md`) | Low | Gem-authored methodology |
| Built-in (`skill.design`, `skill.compose`) | Lowest | Ask-skills defaults |

Discovery happens at agent initialization. All skills are listed in the system prompt with their name and description.

## Testing Skills

To verify your skill is picked up:

```ruby
registry = Ask::Skills.discover(agent_dir: "agents/health_check")
registry.names  # => ["debugging", ...]
```

And to load a skill's instructions into a session manually:

```ruby
session = Ask::Agent::Session.new(model: "gpt-4o")
session.skill("debugging")   # loads the full instructions
```

## Bundling Skills with Gems

Include an `ask/skills/<name>/SKILL.md` path in your gem's `lib/`:

```
my-gem/
└── lib/
    └── ask/
        └── skills/
            └── my-gem-workflow/
                └── SKILL.md
```

These are automatically available to any project using your gem.

## Next Steps

- [Build a custom tool](/ask-docs/extending/custom-tools)
- [Publish a custom service gem](/ask-docs/extending/custom-services)
- [Learn about the skills system](/ask-docs/core/skills)
