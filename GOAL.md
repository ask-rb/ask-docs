# ask-docs — The ask-rb Guides & Documentation Site

## Purpose

The single documentation site for the ask-rb ecosystem — a guide for Ruby
developers building agentic applications. Modeled after Rails Guides
(guides.rubyonrails.org): organized by concept, written as narrative,
accessible to beginners and battle-tested for production.

The site lives at **ask-rb.org** (GitHub Pages), built with Jekyll and the
`just-the-docs` theme — exactly what's already set up.

## Core Principles

1. **Organize by concept, not by gem name.** "LLM Providers" not "ask-llm-providers."
   "Service Contexts" not "ask-github, ask-slack, ask-notion." The gem name is
   infrastructure — the concept is what the user needs.

2. **Tutorials first, reference later.** A new user should hit Getting Started and
   have an agent running in 5 minutes. Deep dives are for when they need them.

3. **Show, don't just tell.** Every page has runnable code examples. The examples
   should be copy-pasteable.

4. **Extending is a first-class citizen.** Not just "how to use the tools" but
   "how to build your own tools, providers, agents, and service gems."

5. **No migration guides from other ecosystems.** We're not here to convert
   users from other tools — we're here to be the best way to build agentic Ruby
   apps, period.

## Target Audience

| Persona | Goal | First Page |
|---|---|---|
| **Ruby newcomer** | "I want to build an agent in Ruby" | Getting Started: Your First Agent |
| **Rails developer** | "I want AI in my Rails app" | Getting Started: Rails + AI |
| **Gem author** | "I want to extend the ecosystem" | Extending: Custom Tools, Providers |
| **Production user** | "I need to monitor & evaluate" | Production: Observability & Evaluation |

## Navigation Structure

The site has **two-level navigation** (collapsible sections), just like Rails Guides:

```
Home (index.md)

Getting Started
├── Your First Agent (getting-started/first-agent.md)
├── AI in Your Rails App (getting-started/rails-ai.md)
└── Core Concepts (getting-started/concepts.md)

Core Components                              ← What the ecosystem provides
├── LLM Providers (core/providers.md)
├── Tools & Execution (core/tools.md)
├── Sandbox Providers (core/sandbox.md)
├── The Agent Loop (core/agent.md)
├── Skills (core/skills.md)
├── Schema & Structured Output (core/schema.md)
└── Credential Resolution (core/auth.md)

Rails Integration (rails/)
├── Setup & Generators (rails/setup.md)
├── Database Tools (rails/database.md)
├── Persistence (rails/persistence.md)
└── Error Services (rails/errors.md)

Service Contexts (services/)
├── GitHub (services/github.md)
├── Slack (services/slack.md)
├── Notion (services/notion.md)
├── Linear (services/linear.md)
└── Building a Service Gem (services/custom.md)

Production (production/)
├── Observability & Events (production/observability.md)
├── Monitoring Dashboard (production/monitoring.md)
├── OpenTelemetry Tracing (production/opentelemetry.md)
└── Evaluating LLM Outputs (production/evaluation.md)

Extending (extending/)                    ← Customization is first-class
├── Custom Tools (extending/custom-tools.md)
├── Custom Providers (extending/custom-providers.md)
├── Custom Agents (extending/custom-agents.md)
├── Custom Service Gems (extending/custom-services.md)
└── Custom Skills (extending/custom-skills.md)

Reference (reference/)
├── Gem Index (reference/gems.md)         ← all 23 gems with descriptions & deps
├── API Reference (reference/api.md)      ← generated or curated per-gem API docs
└── Design & Philosophy (reference/design.md)
```

This replaces the current flat navigation with a concept-based hierarchy.

## Section Details & Content Requirements

### Getting Started

Three pages that teach by doing:

**1. Your First Agent** (getting-started/first-agent.md)
- "Install `gem install ask-agent` and you have an agent"
- Set an API key, create an agent, run a prompt
- Add a tool (Bash or Code), watch the agent use it
- Goal: user has a working agent in under 5 minutes
- Covers: ask-agent, ask-llm-providers, ask-tools-shell

**2. AI in Your Rails App** (getting-started/rails-ai.md)
- "Add `gem 'ask-rails'` to your Rails app"
- Run the generator, configure providers
- Your first agent-in-a-Rails-app — use the database tools
- Goal: Rails developer sees immediate value
- Covers: ask-rails, ask-rails database tools, ask-llm-providers

**3. Core Concepts** (getting-started/concepts.md)
- High-level overview of the architecture
- What is an agent? (session + loop + tools + provider)
- What is a tool? (capability) vs what is a skill? (methodology)
- How providers work
- How service contexts work
- The gem map (visual overview)
- Goal: user understands the mental model of the entire ecosystem

### Core Components

Each page in this section explains one component of the ecosystem.
Format: "What it is → When to use it → How to use it → Key features"

**LLM Providers** (core/providers.md)
- How to configure providers (env vars, ask-auth)
- Available providers (OpenAI, Anthropic, Google, Mistral, Ollama, Bedrock, Cloudflare, OpenRouter)
- Model selection guide (capabilities, cost, context window)
- Streaming, structured output, tool calling
- How providers auto-discover models via models.dev

**Tools & Execution** (core/tools.md)
- The Ask::Tool base class: name, description, params, call/execute
- Shell tools: Bash, Read, Write, Edit, Glob, Grep, Code
- Each tool documented with parameters and examples
- Result types: success, failure, error, halted
- Tool execution: parallel vs sequential, retries, abort

**Sandbox Providers** (core/sandbox.md)
- Why sandboxed execution matters
- Local provider (process isolation + rlimits)
- Docker provider (container security)
- Daytona (remote sandboxes)
- Cloudflare (edge sandboxes)
- How to choose and configure a provider

**The Agent Loop** (core/agent.md)
- Session lifecycle (init → run → complete)
- The think-call-execute loop
- Tool executor (parallel, retries, halt)
- Compaction (context window management)
- Events and hooks (lifecycle instrumentation)
- Error handling (retries, fallbacks, abort)

**Skills** (core/skills.md)
- What are skills? (on-demand methodology vs always-present system prompt)
- Where skills come from (gems, project, user config)
- How to create a skill (file format, frontmatter, instructions)
- How to use skills (auto-discovered, listed in system prompt, loaded on demand)
- Skills are NOT tools (tools give capabilities, skills give methodology)

**Schema & Structured Output** (core/schema.md)
- JSON Schema DSL for tool parameters and structured output
- Basic types, nested schemas, enums, conditionals
- Using with Ask::Tool params
- Using with LLM structured output

**Credential Resolution** (core/auth.md)
- The resolution chain (env → file → Rails credentials → OAuth)
- Built-in providers: env, file, OAuth, database
- How service gems use ask-auth

### Rails Integration

**Setup & Generators** (rails/setup.md)
- Add to Gemfile, run `rails generate ask:rails:install`
- What it creates (initializer, migration)
- Configuration options

**Database Tools** (rails/database.md)
- QueryDatabase: run SQL in the agent's Rails context
- ReadModel: inspect AR models and their associations
- ReadLog: find and parse Rails log entries
- ReadRoutes: examine the route table
- RunCommand: execute shell commands from Rails
- SearchCodebase: full-text code search

**Persistence** (rails/persistence.md)
- Agent sessions backed by ActiveRecord
- In-memory vs database storage
- Session save/load/resume

**Error Services** (rails/errors.md)
- SolidErrors, Sentry, Honeybadger — how each works with ask-rails
- Configuring error monitoring for your agent
- Using error context to help the agent debug

### Service Contexts

Each service page covers: description → auth setup → client usage → error handling

- GitHub (services/github.md)
- Slack (services/slack.md)
- Notion (services/notion.md)
- Linear (services/linear.md)

**Building a Service Gem** (services/custom.md)
- The three-file pattern: context.rb, client.rb, error_guide.rb
- Conventions to follow
- How to use ask-auth for credential resolution
- How to add skills to your service gem

### Production

**Observability & Events** (production/observability.md)
- Ask::Instrumentation: events, subscribe pattern, metadata context
- Cost tracking (subscribe to chat completions)
- Usage analytics
- Logging setup

**Monitoring Dashboard** (production/monitoring.md)
- Rails engine dashboard at /ask/monitoring
- Metrics: cost, throughput, errors, response time
- Alert channels (Slack, email, webhook)
- Configuring alert rules

**OpenTelemetry Tracing** (production/opentelemetry.md)
- How OTel spans map to ask events
- Exporting to Langfuse, Datadog, Honeycomb
- Trace context propagation

**Evaluating LLM Outputs** (production/evaluation.md)
- Why evaluate? (catch regressions, ensure quality)
- Deterministic assertions (contains, regex, JSON, etc.)
- LLM-as-judge assertions (faithful, hallucination, bias, toxicity)
- CI integration (JUnit output, GitHub annotations)
- Cost-aware evaluation

### Extending (Customization)

This section is critical. It teaches users how to make the ecosystem their own.

**Custom Tools** (extending/custom-tools.md)
- Subclass Ask::Tool, use the DSL (description, param, params)
- Implement execute() — what tools can and can't do
- Raise Halt to stop the agent loop
- Error handling conventions
- Testing custom tools (unit + integration)
- Example: building a "weather lookup" tool end-to-end

**Custom Providers** (extending/custom-providers.md)
- Subclass Ask::Provider, implement chat/embed/list_models/api_base/headers
- Register the provider
- Capabilities (what features does your provider support?)
- Streaming, tool calling, image support
- Example: building a provider for a custom API

**Custom Agents** (extending/custom-agents.md)
- When to use Ask::Agent directly vs extend it
- Custom hooks (Hooks class: before_tool, after_tool, before_llm, after_llm)
- Custom events (Event system: emit and subscribe)
- Custom compaction strategy
- Custom persistence backend
- Example: an agent that logs everything to a file

**Custom Service Gems** (extending/custom-services.md)
- Extends services/custom.md — more detailed coverage
- Publishing to RubyGems
- Adding skills to your gem
- Testing with VCR cassettes

**Custom Skills** (extending/custom-skills.md)
- Creating skill files for your project
- Writing effective methodology
- Testing skills (does the agent use them correctly?)

### Reference

**Gem Index** (reference/gems.md)
- Complete table of all 23+ ask-* gems
- Each entry: name, summary, version, dependencies, description
- Optional dependency graph (visual or text)
- Example:
  ```
  | Gem | Version | Depends On | Purpose |
  |---|---|---|---|
  | ask-agent | 0.1.0 | ask-core, ask-tools, ask-tools-shell | Agent loop & sessions |
  | ask-rails | 0.1.0 | ask-agent, rails >= 7.1 | Rails integration |
  | ... | ... | ... | ... |
  ```

**API Reference** (reference/api.md)
- Curated API documentation per gem
- Key classes and methods
- Link to each gem's README for full details
- Can be auto-generated from YARD

**Design & Philosophy** (reference/design.md)
- Port the existing design/index.md content
- Why modular? (each gem does one thing)
- Why service context over pre-built tools?
- Why skills are separate from tools?
- Why ask-rb exists (what problems it solves)

## Pages to Add

11 new pages needed:

| Page | Path | Priority |
|---|---|---|
| Your First Agent | getting-started/first-agent.md | HIGH |
| AI in Your Rails App | getting-started/rails-ai.md | HIGH |
| Core Concepts | getting-started/concepts.md | HIGH |
| Sandbox Providers | core/sandbox.md | HIGH |
| Skills | core/skills.md | MED |
| Schema & Structured Output | core/schema.md | MED |
| Observability & Events | production/observability.md | MED |
| Gem Index | reference/gems.md | HIGH |
| Custom Tools | extending/custom-tools.md | HIGH |
| Custom Providers | extending/custom-providers.md | HIGH |
| Custom Agents | extending/custom-agents.md | MED |
| Custom Service Gems | extending/custom-services.md | MED |
| Custom Skills | extending/custom-skills.md | LOW |
| Build a Service Gem (overview) | services/custom.md | MED |

Existing pages to move/rename:
- `agent/index.md` → move content into `core/agent.md`
- `core/ask-*.md` → some move to `services/`, some keep as-is
- `providers/` → merge into `core/providers.md`, `core/sandbox.md`
- `rails/index.md` → split into `rails/setup.md`, `rails/database.md`, etc.
- `design/index.md` → move to `reference/design.md`

## Jekyll Configuration

The `just-the-docs` theme supports hierarchical navigation via frontmatter.
Remove the flat `navigation:` list from `_config.yml` and use frontmatter in each page:

```yaml
# getting-started/index.md (section index)
---
layout: default
title: Getting Started
nav_order: 1
has_children: true
---

# Getting Started
```

```yaml
# getting-started/first-agent.md (section page)
---
layout: default
title: Your First Agent
parent: Getting Started
nav_order: 1
---

# Your First Agent
```

This means:
1. Each section gets an `index.md` with `has_children: true`
2. Pages within that section get `parent: Section Name`
3. Remove `just_the_docs: navigation:` from `_config.yml`
4. Add `nav_sort: case_sensitive` or keep default sorting

## Tone & Style

Write like Rails Guides: clear, opinionated, Ruby-idiomatic.

**Do:**
- "Run `bundle exec rake test` to verify everything works"
- "A tool is a single capability. A skill is a methodology."
- "If you're using Rails, `ask-rails` wires everything up automatically."

**Don't:**
- "You may optionally wish to..." (weak)
- "In the unlikely event that..." (apologetic)
- "It is important to note that..." (padding)
- Any migration guides or comparisons to other tools

**Voice:**
- Direct and confident: "Do X. Here's why."
- Ruby-flavored: code examples in idiomatic Ruby
- Example-driven: every section has a concrete example
- Short paragraphs, lots of code blocks

## Implementation Order

Phase 1 (foundation):
1. Restructure Jekyll navigation (frontmatter-based, remove flat list)
2. Write Getting Started (3 pages — the most important content)
3. Write Gem Index reference page
4. Add missing core pages (sandbox, skills, schema)

Phase 2 (completeness):
5. Write Production section (observability, monitoring, evaluation)
6. Write Customization section (tools, providers, agents)
7. Move service gem pages to services/ directory
8. Split rails/index.md into proper sub-pages

Phase 3 (polish):
9. Review all 19 existing pages for tone and accuracy
10. Add any missing gem pages (instrumentation, monitoring, etc.)
11. Set up ask-rb.org domain
12. Add search (just-the-docs includes it)

## Keeping Docs in Sync

After each gem reaches a new version:
- Update the Gem Index table
- Update any code examples that changed
- Mark new features in the relevant section page
- This can be automated: a CI check that README examples match docs examples

## What v1.0 of ask-docs Looks Like

| Metric | Target |
|---|---|
| Pages | 30+ (covering all 23 gems + tutorials + extending) |
| Sections | 8 (Getting Started, Core, Rails, Services, Production, Extending, Reference) |
| Navigation | Hierarchical, collapsible, concept-based |
| Code examples | Every page has at least 2 runnable examples |
| Search | Working (built into just-the-docs) |
| Domain | ask-rb.org → GitHub Pages |
| Design | Clean, readable, Rails-inspired |

## Development Workflow

### Git conventions
- Default branch is **master**.
- Use conventional commits.
- Reference existing pages and gems at /Users/kaka/Code/ask-rb/ for patterns.

### Local dev
```bash
cd /Users/kaka/Code/ask-rb/ask-docs
bundle exec jekyll serve  # http://localhost:4000/ask-docs/
```

### Testing
- Test that all internal links work (no broken references)
- Test that code examples are syntactically valid Ruby
- Test that navigation renders correctly
