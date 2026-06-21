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
Reference/         — Gem index, API docs, design philosophy
```

## License

MIT — see [LICENSE](LICENSE).
