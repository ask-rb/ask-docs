---
layout: default
title: Skills
parent: Core Components
nav_order: 5
---

# Skills

**On-demand methodology for agents.** Skills tell the agent *how* to approach a problem — they're instructions loaded into the system prompt when needed.

```ruby
# Skills are NOT code — they're markdown files
# They live in the project, a gem, or user config
```

## What Skills Are

A skill is a markdown file with frontmatter that describes a methodology:

```markdown
---
name: rails-debugging
description: Systematic Rails debugging methodology
---

When asked to debug a Rails application:

1. First check the logs — read log/production.log or use ReadLog
2. Check error tracking — ask about SolidErrors, Sentry, or Honeybadger
3. Reproduce the issue — use the database tools to verify state
4. Identify the root cause — examine the relevant model and controller
5. Propose a fix with a test
```

Skills are methodology. **Tools are capability.** An agent with `Bash`, `Read`, and `Write` tools can do anything, but without methodology skills, it doesn't know the most effective approach.

## Where Skills Come From

Skills are auto-discovered from three sources:

| Source | Location | Priority |
|---|---|---|
| Gems | `shared/ask/skills/` in each gem | Low |
| Project | `.ask/skills/` in the project root | Medium |
| User config | `~/.ask/skills/` | High |

When the agent starts, all skills are listed in the system prompt with descriptions. The LLM decides which to apply based on the user's request.

## Creating a Skill

Create a `.md` file in `.ask/skills/`:

```markdown
---
name: code-review
description: Code review methodology for pull requests
---

## Code Review Process

1. **Understand the change** — read the diff and description
2. **Check for bugs** — edge cases, error handling, nil checks
3. **Verify tests** — does the change have tests? Do they pass?
4. **Review style** — follows project conventions?
5. **Check security** — SQL injection, mass assignment, exposed secrets
6. **Leave actionable feedback** — specific, kind, useful
```

That's it. The agent will automatically discover and use this skill.

## Skills vs Tools

| | Tools | Skills |
|---|---|---|
| **Purpose** | Give capability | Give methodology |
| **Implementation** | Ruby class | Markdown file |
| **When loaded** | Always registered | On demand in system prompt |
| **What they do** | Execute actions | Guide thinking |
| **Example** | `Bash` runs commands | "Reproduce bugs first" |

A tool says "I can run bash commands." A skill says "When debugging, reproduce the issue first, then trace the call stack."

## Ecosystem Skills

The ask-rb ecosystem ships 13+ skills across its gems. Each skill provides domain-specific methodology for the agent:

| Skill | Gem | Purpose |
|---|---|---|
| `skill.compose` | ask-skills | How skills interact, combine, and resolve |
| `skill.design` | ask-skills | How to design and write effective skills |
| `github.use_github` | ask-github | Navigating the GitHub API with Octokit |
| `slack.use_slack` | ask-slack | Navigating the Slack API with slack-ruby-client |
| `notion.use_notion` | ask-notion | Navigating the Notion API with notion-ruby-client |
| `linear.use_linear` | ask-linear | Navigating the Linear API with GraphQL |
| `sentry.use_sentry` | ask-sentry | Navigating the Sentry API |
| `honeybadger.use_honeybadger` | ask-honeybadger | Navigating the Honeybadger Data API |
| `solid_errors.use_solid_errors` | ask-solid_errors | Querying errors, occurrences, and backtraces |
| `providers.model_select` | ask-llm-providers | Selecting the right LLM model |
| `rails.db_debug` | ask-rails | Debugging database performance issues |
| `rails.deploy_pipeline` | ask-rails | Pre-deployment checklist |
| `rails.route_trouble` | ask-rails | Debugging routing issues |
| `shell.patterns` | ask-tools-shell | Shell tool composition patterns |

## Skill Resolution

When the agent initializes:

1. It collects all `.md` files from `SKILL_DIRS` (gem → project → user)
2. Lists them in the system prompt by name and description
3. The LLM chooses which skills to activate based on the task
4. Activated skills are loaded into the system prompt

This is different from a static system prompt — skills are methodology that the agent applies contextually.

## Best Practices

- **One concept per skill.** A skill about "Rails debugging" shouldn't also cover deployment.
- **Write for the LLM.** Use clear, step-by-step instructions. Bullet points work better than paragraphs.
- **Reference tools by name.** The LLM knows its tools, so say "use ReadModel to inspect associations" not "inspect the database schema."
- **Keep skills focused.** A skill should fit in 10-15 bullet points. If it's longer, split it.

## Next Steps

- [Build a custom skill](/extending/custom-skills)
- [Explore service contexts](/services)
- [Learn about the agent loop](/core/agent)
