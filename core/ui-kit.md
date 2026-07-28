---
layout: default
title: UI Kit
parent: Core Components
nav_order: 5
---

# ask-ui-kit

Framework-agnostic Web Components for building AI chat interfaces. Built with [Lit](https://lit.dev) and standard [Custom Elements](https://developer.mozilla.org/en-US/docs/Web/API/Web_Components/Using_custom_elements), these components work in any framework — Rails, Svelte, React, Vue, or plain HTML.

## Installation

```bash
npm install ask-ui-kit
```

### Rails (importmap)

```bash
bin/importmap pin ask-ui-kit
```

```erb
<%= javascript_import_module_tag "ask-ui-kit" %>
```

### Svelte

```bash
npm install ask-ui-kit
```

```svelte
<script>
  import "ask-ui-kit";
</script>
```

## Components

### `<ask-message>`

A chat bubble for user or assistant messages. This is the foundational component — every chat UI starts here.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `role` | `"user" \| "assistant"` | `"user"` | Message role. User messages are right-aligned with a bubble background; assistant messages are left-aligned with no background. |
| `content` | `string` | `""` | Message text content. Rendered as plain text with `white-space: pre-wrap` for preserving line breaks. |

#### Examples

**User message:**
```html
<ask-message role="user" content="Extract all line items from these invoices."></ask-message>
```

**Assistant message:**
```html
<ask-message role="assistant" content="I found 12 line items across 3 invoices."></ask-message>
```

**Rails ERB (with escaping):**
```erb
<ask-message role="user" content="<%= escape_javascript(message.content) %>"></ask-message>
```

**Svelte:**
```svelte
<ask-message role={msg.role} content={msg.content} />
```

**React:**
```tsx
<ask-message role={role} content={content} />
```

#### Dark Mode

The component detects dark mode automatically, no configuration needed:

| Scenario | Applied by |
|----------|-----------|
| System prefers dark | `@media (prefers-color-scheme: dark)` |
| Host app has `.dark` class on `<html>` | `:host-context(.dark)` |
| Host app has `.light` class on `<html>` | Overrides system preference |

#### Theming

Override colors via CSS custom properties on `ask-message` or any parent:

```css
/* Light mode overrides */
ask-message {
  --ask-user-bg: #e5e7eb;
  --ask-user-text: #111827;
  --ask-assistant-text: #111827;
}

/* Dark mode overrides — applied automatically when dark */
ask-message {
  --ask-user-bg-dark: #374151;
  --ask-user-text-dark: #f9fafb;
  --ask-assistant-text-dark: #f9fafb;
}
```

## Architecture

ask-ui-kit uses Shadow DOM for style encapsulation. Each component is a self-contained custom element with no external CSS dependencies.

### How it works

```
┌─────────────────────────────────────────────┐
│  <ask-message role="user">                   │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  │
│  │  #shadow-root                           │  │
│  │  ┌─────────────────────────────────┐    │  │
│  │  │  Tailwind utilities (inlined)    │    │  │
│  │  │  + :host-context theme rules     │    │  │
│  │  └─────────────────────────────────┘    │  │
│  │  ┌─────────────────────────┐            │  │
│  │  │  <div class="flex ...">  │            │  │
│  │  │    Message content      │            │  │
│  │  └─────────────────────────┘            │  │
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘  │
└─────────────────────────────────────────────┘
```

The Tailwind CSS utility classes are compiled at build time and bundled into the component's Shadow DOM. The host app does not need Tailwind — the components work in any project, with any CSS framework or none.

### Principle: Tailwind in the template, CSS only for host-context

Components use Tailwind utility classes in the HTML template for layout and spacing. Custom CSS is reserved for what Tailwind cannot express:
- `:host` styling
- `:host-context(.dark)` / `:host-context(.light)` for theme scoping
- `@media (prefers-color-scheme: dark)` for system dark mode

## Changelog

See [CHANGELOG on GitHub](https://github.com/ask-rb/ask-ui-kit/blob/master/CHANGELOG.md).
