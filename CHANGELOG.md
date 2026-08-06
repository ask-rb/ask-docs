# Changelog

## [0.15.0] — 2026-08-06

### Changed

- **`Ask::Agent::Extensions` → `Ask::Agent::Policies`** (ask-agent 0.28.0).
  The tool-lifecycle policies (ApprovalPolicy, Permissions, RateLimiter,
  AuditLog) are renamed to match their seam, like middleware/stream
  transforms/persistence. The agent guide now explains the taxonomy:
  policies are opt-in, replaceable implementations of the before/after tool
  hook seam; core mechanisms (ApprovalQueue, `:pending` results,
  `approval: true`) stay on Session with `Policies::ApprovalPolicy` as the
  reference policy over them. Update references:
  `Ask::Agent::Extensions::X` → `Ask::Agent::Policies::X`.

## [0.14.0] — 2026-08-05

### Added

- **`Repl` tool: persistent Ruby sessions** (ask-tools-shell 0.4.0). The
  first RLM-style (recursive language model) tool in the ecosystem: a
  long-lived plain-ruby kernel subprocess evaluates code into a shared
  binding, so variables, requires, and defined methods survive across calls
  — the model keeps a working environment instead of starting from scratch
  every time. Named process-wide sessions, `reset:` to discard state,
  per-eval timeout (state lost, fresh respawn), idle recycling, dead-session
  respawn with one retry, and bundler-env-stripped spawn for plain-ruby
  parity with `Code`. Documented with a Code-vs-Repl comparison under
  ask-tools-shell in [core/tools](/ask-docs/core/tools).

## [0.13.0] — 2026-08-03

### Changed

- **Sandboxed commands now run in the caller's working directory**
  (ask-sandbox-providers 0.1.4). Previously every Bash command ran in a
  fresh throwaway temp dir, so a file the Write/Edit tools had just created
  was invisible to it — `ruby hello.rb` after writing it with Write failed
  with `LoadError` and agents had to work around it with absolute paths.
  Now the shell tools share one working directory, like a real terminal.
  `workdir:` still pins a specific directory. The Local provider's security
  list on the sandbox page was updated to match.

### Fixed

- **First-agent example 4 is now a genuinely clean run.** Re-recorded after
  the sandbox fix: the agent writes `hello.rb`, runs `ruby hello.rb`, and it
  succeeds on the first try — the recorded output no longer narrates the
  LoadError workaround.
- **`bin/rerun-example.rb`** — a small script to re-record (or replay) a
  single example block: `FILE=... PATTERN=... ruby bin/rerun-example.rb`
  (add `REPLAY=1` to replay the existing tape without a key).

## [0.12.0] — 2026-08-03

### Changed

- **`gpt-4o` → `deepseek-v4-flash` everywhere.** The docs no longer default
  to the outdated gpt-4o model; all model usage (sessions, chats, catalog
  lookups, prose) uses deepseek-v4-flash. Catalog examples re-ran with the
  real deepseek-v4-flash values (1M context window, `supports?(:vision) =>
  false`, etc.) and prose that named gpt-4o's provider was corrected to
  DeepSeek.
- **Streaming example now actually showcases streaming.** The first-agent
  streaming example asks the agent to run `ruby -e 'p RUBY_VERSION'` and then
  write a short poem about Ruby, so the recorded result is a streamed
  multi-line response (tool events + text deltas) instead of a short array.
- **Long output lines wrap at 80 columns.** The runner word-wraps generated
  output so `# =>` results stay readable without horizontal scrolling,
  hard-breaking only tokens longer than the width.
- **Runner runs each example in a scratch temp dir**, so file-creating
  examples never drop files into the docs tree — the first-agent "more
  tools" example no longer needs a temp-dir wrapper or a comment about it.

### Removed

- "Nothing is fabricated" phrasing from the real-outputs notes (the note
  itself is enough).
- Unnecessary in-example comments (e.g. the temp-dir explanation).

## [0.11.0] — 2026-08-03

### Added

- **A note that every output is real.** The front page and the first-agent
  guide now state that all `# =>` results come from actually running the
  examples against the ask-rb gems and real models — nothing is fabricated.
- **Ruby-specific, personal-information-free examples.** The recorded
  first-agent examples use Ruby tasks every reader resonates with: `ruby -v`,
  creating and running `hello.rb`, and a `ruby -e` one-liner (the old
  "what's the current date and who's the user?" prompt — which leaked the
  machine's username and date — is gone). Illustrative prompts in the agent
  and observability guides now use Ruby examples too (factorials, email
  validation) instead of poems and date lookups.
- **Clean multi-line outputs.** Model responses that span lines now render
  with real newlines (one `# ` per line) instead of `"\n"` escape
  sequences, so the outputs read exactly like the model's text.

### Fixed

- ask-sandbox-providers 0.1.3: the sandbox's `rlimit_nproc` default was 200,
  which is easily exceeded on a busy machine — every fork inside a sandboxed
  command then failed with `Resource temporarily unavailable`, breaking the
  Bash/Code tools for the agent examples. Raised to 1024.
- Multi-line trailing slots (`expr # =>` followed by continuation comment
  lines) are now idempotent: the runner consumes consecutive comment lines as
  part of the slot, so re-running a wrapped multi-line output rewrites it
  cleanly instead of stacking duplicates.
- Wrapped continuation lines no longer get a double `#` prefix (the
  `# # page: 3}}` bug) — the wrapper only prefixes lines it creates itself.

## [0.10.0] — 2026-08-03

### Added

- **first-agent examples 4 & 5 now show real `# =>` outputs.** Both are
  recorded blocks like example 3: "Give it more tools" runs inside a temp
  dir (so the demo `hello.rb` never lands in your project) and shows the
  agent's real response; "Add streaming" shows the streamed final answer.
  Original prompts unchanged.
- **Tool-execution taping for deterministic multi-turn replays.** The
  recorder now tapes tool calls alongside provider calls (ask-eval 0.3.0),
  so a multi-turn agent run replays as a faithful tape — tool results are
  replayed instead of re-executed, which keeps the loop deterministic even
  when a tool would behave differently on a second run (transient failures,
  temp paths, changing files).
- Recordings are named by ordinal within the file (first-agent-1, -2, ...)
  instead of fence line numbers, which shifted when generated output
  changed the line count.

### Fixed

- The recorder hook fired twice per chat call (the module landed twice in a
  provider's ancestry because OpenAI is both registered and an ancestor of
  the OpenAI-compatible classes), misaligning replay tapes. A re-entrancy
  guard makes the outermost prepend record once.
- Streaming example used a nonexistent event class
  (`ToolExecutionComplete` → `ToolExecutionEnd`); running it also exposed an
  ask-agent bug — `String#truncate` (an ActiveSupport extension) used
  without loading it, so bare `require "ask-agent"` streaming raised
  NoMethodError. Fixed in ask-agent 0.25.2 with plain-Ruby truncation.

## [0.9.1] — 2026-08-03

### Added

- **New [App Server](/ask-docs/core/app-server) guide** — ask-app-server:
  the JSON-RPC/stdio app server that exposes an ask-rb agent over the
  standard app-server protocol. Covers what you can build (IDE extensions,
  chat UIs, bots, automation, your own SDK), the protocol methods, events,
  permission interactions, and configuration. Linked from the Core
  Components index and the gem index.
- Open-ended lists: "and more" phrasing where enumerations are examples
  rather than complete sets (MCP clients, agent use cases), so the docs
  don't imply a definitive list.

### Changed

- App Server guide rewritten around what the protocol is for (embedding an
  agent in your own product), presented as a vendor-neutral standard — Codex
  and OpenAI's SDKs appear only as examples of existing app-server
  implementations/clients, not as the reason ask-app-server exists; removed
  mentions of niche internal/ecosystem projects (zcode-telegram-bot,
  ai-sdk-provider-codex-app-server) and the "drop-in replacement" framing.

## [0.9.0] — 2026-08-03

### Changed

- **`Ask::Result` is now the single result type for the whole ecosystem.**
  ask-core owns it with both the foundational API (`success`/`failure`/
  `aborted`/`blocked`) and the tool API (`ok`/`error`); ask-tools now depends
  on ask-core instead of redefining the class. This fixes the collision where
  `Ask::Result.success` raised `ArgumentError` in any app loading both gems,
  and fixes `ask-rag`'s embedding pipeline (`raw.output` on provider results).
  Updated the API reference and tools guides to show the union.
- **New [Architecture & Ownership](/ask-docs/reference/architecture) page** —
  the gem layering and the ownership rule: shared value objects and base
  contracts live in ask-core (zero-dependency); feature gems extend, never
  redefine.

## [0.8.0] — 2026-08-03

### Added

- **Real `# =>` outputs everywhere concrete examples appear.** Ask-core
  (Conversation, Streaming, Provider interface, Role mapping, Model Catalog,
  ModelInfo, Provider override, Document, multi-modal Content, errors),
  schema (nested schemas, optional/nullable fields, reusable definitions,
  conditionals, tool params, validation), providers (registration,
  capabilities introspection, model catalog, aliases), tools (`Ask::Result`,
  the `Ask::Tools` registry), and the API reference (Provider, Conversation,
  Message, Stream, ModelCatalog, ToolDef, Result, errors) now carry outputs
  verified by running the real gems.
- **Invisible block markers.** `# recorded` / `# not-verified` in-code
  comments are replaced by `<!-- docs-example: ... -->` HTML comments on the
  line before the fence, which kramdown renders invisibly — readers see only
  clean code plus real outputs.
- **Per-file process isolation for the runner.** Each markdown file now runs
  in its own Ruby process, so an example loads only the gems that page
  requires — matching what a reader following that page alone would
  experience. This also fixes cross-file state bleed (e.g. ask-core and
  ask-tools both define `Ask::Result`; loading both in one process breaks
  each other's factories).
- **Faithful stream replay.** The recorder hook now yields recorded chunks to
  the caller's stream block, so agent-loop examples (`session.run`) replay
  their full response instead of an empty string.

### Fixed

- Docs bugs the new outputs exposed: the nested-schema example used
  `array :comments, of: :object` (correct form is `array :comments do
  object do ... end end`); `Conversation#add_message` / `#messages` don't
  exist (the real API is `system`/`user`/`assistant`/`tool_result` +
  `size`/`last`); `Stream#transcript` is `Stream#accumulated_text`.
- Runner rewrite applied replacements in file order, so a multi-line slot
  that changed the line count shifted every later block's indices and
  corrupted them. Replacements are now applied bottom-up across the whole
  file.

## [0.7.0] — 2026-08-03

### Added

- **Recorder integration for live LLM examples.** Blocks marked `# recorded`
  are taped with ask-eval's Recorder into `examples/recordings/` during
  `rake docs:generate` (with a key) and replayed during `rake docs:verify`,
  so live-LLM examples are now verified with no key and no network. The
  runner hooks every registered provider class, which covers both sessions
  and direct `provider.chat` calls. The first-agent and providers examples
  use this; their outputs are now deterministic.

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
