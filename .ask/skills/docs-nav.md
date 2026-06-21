---
name: docs-nav
description: Navigation and structure conventions for the ask-rb documentation site
---

When creating or restructuring documentation pages:

1. **Section index pages** must have `has_children: true` in frontmatter and a `nav_order` that places them in the correct position.
2. **Child pages** must have `parent: Section Name` matching the parent's `title:`.
3. **Nav order** follows the case-sensitive sorting: Getting Started (1), Core Components (2), Rails Integration (3), Service Contexts (4), Production (5), Extending (6), Reference (7).
4. **Every section index** includes a table linking to its child pages with one-line descriptions.
5. **Every child page** includes a "Next steps" section that cross-links to related pages.
