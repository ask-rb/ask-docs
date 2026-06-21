---
layout: default
title: Custom Skills
parent: Extending
nav_order: 5
---

# Custom Skills

Create skill files that teach your agent methodology. Skills are markdown files with frontmatter — no Ruby code needed.

## What Makes a Good Skill

A skill is most valuable when it teaches the agent *how* to approach a domain-specific problem:

- **Project conventions** — code style, testing patterns, commit format
- **Debugging workflows** — how to investigate specific types of issues
- **Domain knowledge** — business logic, regulations, terminology
- **Process documentation** — deployment steps, review checklists

## Quick Start

Create `.ask/skills/debugging.md` in your project:

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

That's it. The agent will discover and use this skill automatically.

## Skill Frontmatter

```yaml
---
name: rails-deployment          # Required. Used by the agent to identify the skill
description: >-                 # Required. Shown in the agent's system prompt
  Rails deployment process and rollback procedure
priority: high                  # Optional. Default: normal. Options: high, normal, low
tags:                           # Optional. For organization
  - rails
  - deployment
  - production
---
```

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
.ask/
└── skills/
    ├── debugging.md              # General debugging
    ├── rails-conventions.md       # Rails project patterns
    ├── database-migrations.md     # Migration best practices
    └── code-review.md             # PR review checklist
```

## Auto-Discovery

Skills are auto-discovered from:

| Location | Priority | Purpose |
|---|---|---|
| `Gem` shared/skills/ | Low | Gem-authored methodology |
| `.ask/skills/` | Medium | Project-specific methodology |
| `~/.ask/skills/` | High | Personal methodology |

Discovery happens at agent initialization. All skills are listed in the system prompt with their name and description.

## Testing Skills

To verify your skill is being used:

```ruby
session = Ask::Agent::Session.new(model: "gpt-4o")
session.run("Debug this: User creation fails with a validation error")

# Check that the skill was activated
session.activated_skills  # => ["debugging"]
```

## Bundling Skills with Gems

Include a `.ask/skills/` directory in your gem:

```
my-gem/
├── .ask/
│   └── skills/
│       ├── my-gem-workflow.md
│       └── my-gem-troubleshooting.md
```

These are automatically available to any project using your gem.

## Next Steps

- [Build a custom tool](/extending/custom-tools)
- [Publish a custom service gem](/extending/custom-services)
- [Learn about the skills system](/core/skills)
