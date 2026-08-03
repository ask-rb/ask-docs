# ask-rb Guides

Documentation website for the [ask-rb](https://github.com/ask-rb) ecosystem — a suite of Ruby gems for building LLM-powered applications.

Built with [Jekyll](https://jekyllrb.com/) and the [Just the Docs](https://just-the-docs.com/) theme.

## Development

```bash
bundle install
bundle exec jekyll serve --livereload
```

Open http://localhost:4000/ask-docs/ in your browser.

## Structure

Pages are organized by concept, not by gem name:

```
Getting Started/   — First agent, Rails integration, core concepts
Core/              — Providers, tools, sandboxes, agent loop, MCP, schema, auth
Rails/             — Setup, database tools, persistence, errors
Services/          — GitHub, Slack, Notion, Linear, Sentry, Honeybadger
Production/        — Observability, monitoring, tracing, evaluation
Extending/         — Custom tools, providers, agents, services, skills
Reference/         — Gem index, API documentation, design philosophy
```

## Example outputs

Code examples in the docs carry real outputs (`# =>` comments). A runner
executes the runnable ones against the ask-* gems (found as sibling repos)
and keeps those outputs current:

```bash
# Dry run; exits 1 if any example output is stale
rake docs:verify

# Rewrite the markdown files with the real outputs
rake docs:generate

# One file at a time
FILE=core/tools.md rake docs:verify
```

Conventions:

- A fenced ruby block whose first line is `require "ask..."` is runnable.
- A line ending in `# =>` is an output slot; the generator replaces its
  value with the real result. A bare `# =>` comment block right after a code
  line is also a slot — the code line is the expression (used for multi-line
  pretty-printed values).
- An HTML comment directly before the fence controls how a block runs; the
  markers render invisibly, so readers see only clean code and real outputs:
  - `<!-- docs-example: not-verified -->` — skip (Rails-bound snippets, live
    web search, examples whose output is intentionally illustrative).
  - `<!-- docs-example: recorded -->` — make live LLM calls, taped with
    ask-eval's Recorder into `examples/recordings/`. Generate (with a key)
    records; verify replays, so the block is checked with no key and no
    network.
- Each markdown file runs in its own process, so an example loads only the
  gems that page requires — the same environment a reader following that
  page would have.
- Keyed examples skip automatically when the key is missing. Copy
  `.env.example` to `.env` (gitignored) and fill in keys to run them
  locally.

## License

MIT — see [LICENSE](LICENSE).
