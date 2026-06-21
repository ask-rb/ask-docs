---
name: docs-writing
description: How to write, review, and maintain documentation for the ask-rb ecosystem
---

When asked to write or update documentation:

1. **Organize by concept, not by gem name.** Always lead with what the user needs to accomplish, not which gem provides it.
2. **Start with a working example.** Every page needs a copy-pasteable code example in the first third of the page.
3. **Show tool composition.** Don't just list tools — show how they work together. Example: "Use ReadModel to find the schema, then QueryDatabase to verify."
4. **Use active voice.** "Run `bundle exec rake test`" not "Tests can be run by executing..."
5. **Keep paragraphs short.** 2-3 sentences max. Follow with a code block.
6. **Reference real gems and tools.** Use actual class and method names, not placeholders.
7. **Cross-link sections.** Every page should link to related concepts at the bottom.
8. **Avoid comparisons.** Don't compare ask-rb to other tools or frameworks.
