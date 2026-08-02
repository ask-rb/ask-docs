# Changelog

## [0.6.0] — 2026-08-02

### Added

- **Executable examples runner** (`rake docs:generate` / `rake docs:verify`).
  Runnable ruby blocks (first line `require "ask..."`) are executed against
  the ask-* gems and their `# =>` output slots are filled with real results.
  Blocks marked `# not-verified` are skipped; keyed examples skip when the
  key is missing. Copy `.env.example` to `.env` (gitignored) for local keys.
- Real generated outputs in the getting-started agent example and the
  providers quick start (OpenCode Go / deepseek-v4-flash).
- `# not-verified` markers on non-runnable blocks: Rails-bound tools,
  credential examples (output would be a secret), live web search,
  embedding pipelines, and the Minitest examples.

### Fixed

- `Workflow.call(order: order)` → `Workflow.call({ order: order })` in the
  graph quick start and the Rails app guide (the API takes a positional
  input hash).
- `require "ask/opentelemetry"` → `require "ask/open_telemetry"`.
- `Ask::MCP::Client.stdio` → `Ask::MCP.from_stdio` in the Rails MCP guide.
- Missing `require "ask-agent"` in the persistence example.
- Broken multi-line `# =>` slot in the sandbox quick start.
- ask-agent 0.25.1: `Session` was passing raw tool classes to `Chat`,
  crashing on first run with `Ask::InvalidToolDefinition`. Tools now
  resolve before the Chat is built.

## [0.5.0] — 2026-08-02

### Changed

- **READMEs become front doors.** Every ask-* gem README was restructured to
  the front-door shape (what, install, quick start, essential API, links to
  the docs site). Deep content now lives here. The Gem Index's purpose
  column was compressed to one-liners with guide links, so no fact is
  stated twice.

## [0.4.0] — 2026-08-02

### Changed

- **Legacy `.agents/skills/` path removed** (ask-skills 0.5.0). Project skills
  now live in `agents/shared/skills/` (or `app/agents/shared/skills/` in
  Rails). Updated the skills pages, the agent skills table, and the API
  reference discovery list to match.

## [0.3.0] — 2026-08-02

### Changed

- **Accuracy pass across the whole site** — every page re-checked against the
  current gem codebases (ask-agent 0.25.0, ask-llm-providers 0.10.1, ask-core
  0.8.0, ask-rails 0.15.3, and the rest).
  - Getting started: first-agent now covers the 33 supported providers (not
    just OpenAI/Anthropic), installs both `ask-agent` and `ask-tools-shell`,
    and uses the 8-tool shell set (including ApplyPatch).
  - Core: removed the deleted `Ask::Tools::SubAgent` section, fixed the shell
    tool namespaces, corrected skill discovery paths and priority, documented
    ask-mcp's server side, fixed ask-core's contents (auth and cost
    calculation live in other gems), and fixed the ask-ui-kit bundle table.
  - Production: observability, monitoring, and OpenTelemetry pages rewritten
    to match the real APIs (real event classes, `ask:monitoring:install`
    generator, `Ask::OpenTelemetry.install`, actual alert rule shape).
  - Evaluation: documented ask-eval 0.2.0 (SessionEval, eval_session,
    Recorder replay).
  - Reference: gem index now covers all 30+ gems including ask-graph,
    ask-rails-harness-mcp, ask-app-server, ask-acp, ask-coding-providers,
    ask-channel-providers, and the ask-ui-kit npm package; corrected the
    dependency graph and the agent definition convention (`HealthCheck::Agent`).

## [0.2.0] — 2026-07-24

### Added

- **Evaluator documentation** — New section on `core/agent.md` covering the
  `Ask::Agent::Evaluator` class: generator/evaluator separation, quick start,
  three verdicts (accept/revise/block), custom rubrics, events, and configuration.
- **Gem index update** — `reference/gems.md` updated to mention the Evaluator
  in the ask-agent description.

## [0.1.0] — 2026-06-21

### Added

- Initial documentation site for the ask-rb ecosystem
- Getting Started guide: first agent, Rails integration, core concepts
- Core Components: providers, tools, sandboxes, agent loop, MCP, schema, auth, skills
- Rails Integration: setup, database tools, persistence, error services
- Service Contexts: GitHub, Slack, Notion, Linear, Sentry, Honeybadger, SolidErrors
- Production guide: observability, monitoring, OpenTelemetry, evaluation
- Extending guide: custom tools, providers, agents, services, skills
- Reference: gem index, API documentation, design philosophy
