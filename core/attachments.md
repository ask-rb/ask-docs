---
layout: default
title: Attachments & file inputs
parent: Core Components
nav_order: 12
---

# Attachments & file inputs

User→agent file uploads, first-class: attach files to messages and let the
agent (or just its context) know about them.

## Two delivery modes

Every attachment has a delivery mode:

| Mode | What the model receives | When to use |
|---|---|---|
| `:inline` (default) | The file **bytes** (base64, data URI, provider file reference) via the provider's serializers | The agent should read/analyze the file (images, PDFs, documents) |
| `:context` | Only a **manifest line** — `[Attached file: name (mime, N bytes)]` — as plain text | The agent must **know the file exists** but never read it (e.g. a requirements-gathering assistant that must not analyze files) |

`:context` is provider-agnostic (it's just text — every model accepts it) and
never triggers the modality gate. `:inline` is checked against the model's
input modalities and raises `Ask::Agent::UnsupportedAttachmentError` when the
model cannot receive the file type.

## Creating attachments

`Ask::Attachment` accepts exactly one source:

```ruby
Ask::Attachment.new(path: "receipt.png")                          # local path
Ask::Attachment.new(url: "https://example.com/invoice.pdf")       # URL
Ask::Attachment.new(url: "data:text/csv;base64,YSxiCg==")         # data URI
Ask::Attachment.new(data: raw_bytes, filename: "rows.csv",        # raw bytes
                    mime_type: "text/csv")
Ask::Attachment.new(io: File.open("notes.txt"))                   # IO/StringIO
Ask::Attachment.new(blob: work_request.source_files.first)        # duck-typed blob
                                                                  # (download/read/path — e.g. ActiveStorage)
Ask::Attachment.new(file_id: "file-abc123", filename: "doc.pdf",  # provider-managed file
                    mime_type: "application/pdf")
```

Filename and MIME type are derived when not given (extension first, then
magic-byte sniffing for images/PDFs/audio). `attachment.type` classifies the
file (`:image`, `:audio`, `:video`, `:pdf`, `:document`, `:text`, `:unknown`).

## Attaching files to messages

```ruby
chat = Ask::Agent::Chat.new(model: "gpt-4o")

chat.add_message(
  role: :user,
  content: "What's in this file?",
  attachments: [Ask::Attachment.new(path: "invoices.pdf")]
)
```

The attachments merge into the message's content blocks (text stays a text
block; files become `Ask::Content::File` / media blocks), so the existing
provider serializers receive them. The same `attachments:` keyword works on:

- `Chat#ask(message, attachments:)`
- `Session#run(message, attachments:)`
- `Session#steer(message, attachments:)` — applied when the session is idle
  (queued steers keep the message text only)

`Ask::Attachment.wrap` / `wrap_all` coerce paths, hashes, blobs, and content
blocks automatically, so you can pass `["invoices.pdf", blob]` directly.

## Context-only mode (the "know it exists" pattern)

```ruby
session.run(
  "The customer uploaded their utility bills.",
  attachments: [Ask::Attachment.new(blob: bills.first, delivery: :context)]
)
```

The model sees:

```
[Attached file: utility-bill-sep.csv (text/csv, 69 bytes)]
```

No bytes leave your app, every provider accepts it, and the modality gate is
skipped. This is the right pattern for agents whose instructions forbid
reading files — e.g. kawifiles' requirements-gathering agent.

## Provider support (`:inline`)

| Provider | Images | Audio | PDF / documents |
|---|---|---|---|
| OpenAI (chat completions) | `image_url` (URL/base64) | `input_audio` | text fallback (chat completions has no file carrier) |
| OpenAI (Responses / Codex) | `input_image` | — | `input_file` (data URI, URL, or `file_id`) |
| Anthropic | `image` (base64/url) | text note | `document` (base64/text/url/file source) |
| Gemini | `inlineData` / `fileData` | `inlineData` | `inlineData` (base64) or `fileData` (URI); text files inlined |

Unsupported combinations degrade to a descriptive text note (never silently
dropped), and the modality gate catches model-level incompatibilities before
the request is built.

## Persistence

Content blocks survive `Session#persist!` / `Session.load` / checkpoints:
blocks are stored as their `to_h` hashes and reconstructed via
`Ask::Content.from_h` — attachments round-trip through state stores.

## Related patterns

- **Workspace manifests** (the "files landed somewhere" pattern): upload
  files into a directory the agent can reach, then tell it where — useful
  when the agent reads files with tools rather than via the model. The
  `:context` mode is the lightweight variant for "just know it exists".
- **Artifacts** (`Session.new(artifacts: true)`) are the reverse direction:
  tool-produced files delivered back to the app.
