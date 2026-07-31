---
layout: default
title: UI Kit
parent: Core Components
nav_order: 5
---

# ask-ui-kit

Framework-agnostic Web Components for building AI chat interfaces. Built with [Lit](https://lit.dev) and standard [Custom Elements](https://developer.mozilla.org/en-US/docs/Web/API/Web_Components/Using_custom_elements), these components work in any framework — Rails, Svelte, React, Vue, or plain HTML. Now published as an unscoped package.

## Installation

```bash
npm install ask-ui-kit
```

### Rails (importmap)

```ruby
# config/importmap.rb
pin "ask-ui-kit", to: "https://unpkg.com/ask-ui-kit@0.3.0/dist/index.js"
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

### Plain HTML

```html
<script type="module">
  import "https://unpkg.com/ask-ui-kit@0.3.0/dist/index.js";
</script>
```

## Components

### `<ask-message>`

A chat bubble for user or assistant messages.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `role` | `"user" \| "assistant"` | `"user"` | Message role. User messages right-aligned with a bubble background; assistant messages left-aligned with flat text. |
| `content` | `string` | `""` | Message text. Rendered as plain text with `white-space: pre-wrap`. |

```html
<ask-message role="user" content="Extract all line items from these invoices."></ask-message>
<ask-message role="assistant" content="I found 12 line items across 3 invoices."></ask-message>
```

**Rails ERB** — use `html_escape` (Rails default `<%= %>`), not `escape_javascript`:
```erb
<ask-message role="user" content="<%= message.content %>"></ask-message>
```

**Svelte:**
```svelte
<ask-message role={msg.role} content={msg.content} />
```

---

### `<ask-thinking>`

A collapsible reasoning block that shows the model's internal chain-of-thought.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `content` | `string` | `""` | The thinking/reasoning text |
| `label` | `string` | `"Thought"` | Header label text |
| `open` | `boolean` | `false` | Whether the body is expanded |
| `streaming` | `boolean` | `false` | Show animated dots and auto-expand for in-progress reasoning |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-toggle` | `{ open }` | Fired when the user toggles the block |

```html
<ask-thinking content="The user needs extraction of 3 PDF invoices..."></ask-thinking>

<!-- Streaming (in-progress reasoning) -->
<ask-thinking streaming label="Thinking" content="Analyzing the request..."></ask-thinking>
```

---

### `<ask-code-block>`

A code block with a language label and a hover-reveal copy button.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `code` | `string` | `""` | The code content |
| `language` | `string` | `""` | Language label (e.g. "javascript", "ruby") |

```html
<ask-code-block language="ruby" code='puts "Hello, world!"'></ask-code-block>
<ask-code-block code="npm install @ask-rb/ask-ui-kit"></ask-code-block>
```

---

### `<ask-chat-input>`

An auto-resizing chat input with send/stop buttons and keyboard shortcuts.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `value` | `string` | `""` | Textarea content |
| `placeholder` | `string` | `"Type a message..."` | Placeholder text |
| `disabled` | `boolean` | `false` | Disables the textarea |
| `streaming` | `boolean` | `false` | Shows stop button instead of send button |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-submit` | `{ value }` | Fired on Enter (not Shift+Enter) |
| `ask-stop` | — | Fired when stop button clicked or Escape pressed during streaming |
| `ask-input` | `{ value }` | Fired on every input change |

```html
<ask-chat-input></ask-chat-input>
<ask-chat-input streaming></ask-chat-input>
```

```javascript
input.addEventListener("ask-submit", (e) => {
  sendMessage(e.detail.value);
});
```

**Keyboard shortcuts:**
- `Enter` → submit
- `Shift+Enter` → newline
- `Escape` (during streaming) → stop

---

### `<ask-streaming>`

Displays streaming content with a blinking cursor. Hidden when not active.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `content` | `string` | `""` | The streamed text |
| `active` | `boolean` | `false` | Show/hide the element |

```html
<ask-streaming active content="Generating response..."></ask-streaming>
```

**Controller usage:**
```javascript
const el = document.querySelector("ask-streaming");
el.setAttribute("active", "");
el.content = "Hello...";
el.content += " world";
el.removeAttribute("active"); // hide when done
```

---

### `<ask-tool-call>`

Displays a tool call with status (running/done/failed) and elapsed time.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `string` | `"Tool"` | Tool name |
| `status` | `"running" \| "done" \| "failed"` | `"running"` | Current status |
| `duration` | `number` | `0` | Elapsed time in milliseconds |

```html
<ask-tool-call name="Read File" status="running"></ask-tool-call>
<ask-tool-call name="Extract Data" status="done" duration="1234"></ask-tool-call>
<ask-tool-call name="Process PDF" status="failed" duration="567"></ask-tool-call>
```

---

### `<ask-error>`

An error banner with optional retry button.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `message` | `string` | `""` | Error description (renders nothing if empty) |
| `title` | `string` | `"Something went wrong"` | Error heading |
| `retryable` | `boolean` | `false` | Show a Retry button |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-retry` | — | Fired when retry button is clicked |

```html
<ask-error message="Server returned 500" retryable></ask-error>
<ask-error title="Connection Failed" message="Could not reach the server"></ask-error>
```

---

### `<ask-avatar>`

Displays a user/assistant avatar — image, initials, or fallback icon.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `src` | `string` | `""` | Image URL |
| `name` | `string` | `""` | Name for initials fallback (shows first letter) |
| `role` | `"user" \| "assistant"` | `"assistant"` | Fallback icon for role |
| `size` | `number` | `28` | Width/height in pixels |

```html
<ask-avatar src="https://example.com/photo.jpg" name="User"></ask-avatar>
<ask-avatar name="Kaka Kaka" role="user"></ask-avatar>
<ask-avatar role="assistant"></ask-avatar> <!-- shows 🤖 -->
```

---

### `<ask-attachment>`

A file attachment chip with type icon, name, size, and optional remove button.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `name` | `string` | `""` | Filename |
| `size` | `number` | `0` | File size in bytes |
| `type` | `string` | `""` | MIME type (affects icon: image → thumbnail, pdf → 📕) |
| `src` | `string` | `""` | Image preview source |
| `removable` | `boolean` | `false` | Show remove button |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-remove` | `{ name }` | Fired when remove button clicked |

```html
<ask-attachment name="report.pdf" size="1048576" type="application/pdf" removable></ask-attachment>
<ask-attachment name="photo.jpg" size="512000" type="image/jpeg" removable></ask-attachment>
```

---

### `<ask-suggestions>`

A row of clickable suggestion chips for follow-up prompts.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `suggestions` | `string` | `""` | JSON array of strings, e.g. `'["What files?","Help me"]'` |
| `label` | `string` | `"Suggestions"` | Section heading (hidden if suggestions empty) |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-select` | `{ suggestion }` | Fired when a chip is clicked |

```html
<ask-suggestions suggestions='["What files?","Show code","Explain this"]'></ask-suggestions>
```

---

### `<ask-model-selector>`

A styled `<select>` dropdown for choosing AI models.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `options` | `string` | `""` | JSON array of `{label, value}` objects |
| `value` | `string` | `""` | Currently selected value |
| `label` | `string` | `""` | Optional label text before the select |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-change` | `{ value }` | Fired when selection changes |

```html
<ask-model-selector label="Model"
  options='[{"label":"GPT-4","value":"gpt4"},{"label":"Claude 3","value":"claude3"}]'
  value="claude3">
</ask-model-selector>
```

---

### `<ask-markdown>`

Renders inline markdown to HTML. Supports **bold**, *italic*, `code`, and [links](url). For full markdown (tables, headings, lists), pass pre-rendered HTML via the `html` attribute.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `content` | `string` | `""` | Raw markdown text (parsed inline) |
| `html` | `string` | `""` | Pre-rendered HTML (used instead of `content` if provided) |

```html
<ask-markdown content="Hello **world** — this is *great*!"></ask-markdown>
<ask-markdown html="<strong>Pre-rendered</strong> HTML content"></ask-markdown>
```

---

### `<ask-file-upload>`

A click-to-attach file upload zone that renders selected files as `<ask-attachment>` chips.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `accept` | `string` | `""` | Accepted file types (e.g. `".pdf,.jpg"`) |
| `multiple` | `boolean` | `true` | Allow multiple file selection |
| `disabled` | `boolean` | `false` | Disable interaction |
| `files` | `string` | `""` | JSON array of `{name, size, type, src?}` |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-files-select` | `{ files }` | Fired when files are selected |
| `ask-file-remove` | `{ name }` | Fired when a file chip is removed |

```html
<ask-file-upload accept=".pdf,.csv,.xlsx"></ask-file-upload>
```

---

### `<ask-conversation-list>`

A sidebar conversation list with open/closed sections, search, and active highlighting.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `items` | `string` | `""` | JSON array of `{id, title, messageCount?, timestamp?, status?}` |
| `activeId` | `string` | `""` | ID of the currently active conversation |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-select` | `{ id }` | Fired when a conversation is clicked |

```html
<ask-conversation-list
  items='[{"id":"1","title":"Hello World","messageCount":3,"timestamp":"2026-07-28T12:00:00Z","status":"open"}]'
  activeId="1">
</ask-conversation-list>
```

---

### `<ask-voice-input>`

A microphone button with recording animation and elapsed timer.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `recording` | `boolean` | `false` | Recording state (shows stop button + timer) |
| `disabled` | `boolean` | `false` | Disable the button |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-record-start` | — | Fired when recording starts |
| `ask-record-stop` | `{ elapsed }` | Fired when recording stops (elapsed seconds) |

```html
<ask-voice-input></ask-voice-input>
<ask-voice-input recording></ask-voice-input>
```

---

### `<ask-scroll-bottom>`

A floating down-arrow button that appears when scrolled up, with a new-messages badge count.

| Attribute | Type | Default | Description |
|-----------|------|---------|-------------|
| `visible` | `boolean` | `false` | Show/hide the button with animation |
| `badge` | `number` | `0` | New messages count (capped at "99+") |

| Event | Detail | Description |
|-------|--------|-------------|
| `ask-scroll` | — | Fired when the button is clicked |

**Stimulus controller integration:**
```erb
<ask-scroll-bottom data-action="ask-scroll->chat#scrollToBottom"></ask-scroll-bottom>
```

```javascript
// Show when scrolled up
messages.addEventListener("scroll", () => {
  const dist = messages.scrollHeight - messages.scrollTop - messages.clientHeight;
  scrollBtn.visible = dist > 100;
}, { passive: true });

// Scroll on click
scrollBtn.addEventListener("ask-scroll", () => {
  messages.scrollTo({ top: messages.scrollHeight, behavior: "smooth" });
});
```

```html
<ask-scroll-bottom visible badge="3"></ask-scroll-bottom>
```

---

## Dark Mode

---

## Dark Mode

All components automatically support dark mode:

| Scenario | Applied by |
|----------|-----------|
| System prefers dark | `@media (prefers-color-scheme: dark)` |
| Host app has `.dark` class on `<html>` | `:host-context(.dark)` |
| Host app has `.light` class on `<html>` | Overrides system preference |

## Theming

Override colors via CSS custom properties. Each component documents its variables in the source. The naming convention is:

```
--ask-{component}-{property}
--ask-{component}-{property}-dark   (dark mode override)
--ask-{component}-{property}-light  (light mode override)
```

Example — customizing `ask-message`:
```css
ask-message {
  --ask-user-bg-light: #e5e7eb;
  --ask-user-text-light: #111827;
  --ask-user-bg-dark: #374151;
  --ask-user-text-dark: #f9fafb;
}
```

## Architecture

All components use Shadow DOM for style encapsulation. Each is a self-contained LitElement with no external CSS dependencies. Styles use descriptive class names and CSS custom properties for theming (not Tailwind).

```html
<!-- Usage in any framework -->
<ask-message role="user" content="Hello"></ask-message>
```

```
┌────────────────────────────────┐
│  <ask-message>                 │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐│
│  │  #shadow-root             ││
│  │  ┌─────────────────────┐  ││
│  │  │  CSS custom props   │  ││
│  │  │  + host-context     │  ││
│  │  │  + media queries    │  ││
│  │  └─────────────────────┘  ││
│  │  ┌─────────────────────┐  ││
│  │  │  <div class="...">  │  ││
│  │  │    Content          │  ││
│  │  └─────────────────────┘  ││
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘│
└────────────────────────────────┘
```

## Bundle size

| Version | Size (uncompressed) | Size (gzip) |
|---------|---------------------|-------------|
| 0.1.0 | 27 kB | 8 kB |
| 0.2.0 | 100 kB | 19.5 kB |

The increase from 0.1.0 covers 14 additional components. Each component is lazy by default — the bundle is loaded once and all components register themselves via `customElements.define()`.

## Changelog

See [CHANGELOG on GitHub](https://github.com/ask-rb/ask-ui-kit/blob/master/CHANGELOG.md).
