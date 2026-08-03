---
layout: default
title: RAG Pipeline
parent: Core Components
nav_order: 10
---

# RAG Pipeline

**ask-rag** gives you everything you need to build Retrieval-Augmented Generation applications — load documents from files, split them into chunks, store embeddings in a vector store, and retrieve relevant context to ground your LLM's answers.

```ruby
gem "ask-rag"
```

---

## Quick Start

Here's the full pipeline end-to-end:

<!-- docs-example: not-verified -->
```ruby
require "ask-rag"

# 1. Load a document
loader = Ask::RAG::Loader::Text.new
docs = loader.load("README.md")

# 2. Split into chunks
splitter = Ask::RAG::TextSplitter::RecursiveCharacter.new(
  chunk_size: 500, chunk_overlap: 50
)
chunks = splitter.split_documents(docs)

# 3. Embed and store
store = Ask::RAG::VectorStore::InMemory.new
store.add(chunks, model: "text-embedding-3-small")

# 4. Search
results = store.similarity_search("How do I install this?", limit: 3)
results.each do |doc|
  puts "[#{doc.metadata[:score].round(3)}] #{doc.content[0..80]}..."
end
```

---

## Documents

The fundamental unit in ask-rag is the `Ask::Document`. It's a frozen value object with three fields:

```ruby
doc = Ask::Document.new(
  content: "Ruby was created by Matz in 1995.",
  metadata: { source: "history.pdf", page: 3, author: "Matz" },
  id: "doc_abc123"
)

doc.content   # => "Ruby was created by Matz in 1995."
doc.metadata  # => { source: "history.pdf", page: 3, author: "Matz" }
doc.id        # => "doc_abc123"
doc.to_h      # => { content: "...", metadata: {...}, id: "doc_abc123" }
```

Documents are immutable — once created, they cannot be modified. Equality is based on `content` and `metadata` (the `id` is ignored for equality).

Documents flow through every stage of the pipeline:

```
Loader → Document → Splitter → [Document, Document, ...] → Embedder → VectorStore
                                                                              ↓
                                                                     Similarity Search
                                                                              ↓
                                                                       [Document, ...]
```

---

## Loaders

Loaders read files and return arrays of `Ask::Document`. Each loader handles a specific file format.

### Built-in Loaders

| Loader | File type | Requirement |
|---|---|---|
| `Ask::RAG::Loader::Text` | Plain text (.txt) | None |
| `Ask::RAG::Loader::Markdown` | Markdown (.md) | None |
| `Ask::RAG::Loader::CSV` | Comma-separated values (.csv) | `csv` gem |
| `Ask::RAG::Loader::JSON` | JSON documents (.json) | `json` gem |
| `Ask::RAG::Loader::HTML` | HTML pages (.html) | `nokogiri` gem |
| `Ask::RAG::Loader::PDF` | PDF documents (.pdf) — one doc per page | `pdf-reader` gem |
| `Ask::RAG::Loader::Directory` | Recursive directory walk | None (uses other loaders) |

Loaders that need an external gem are skipped automatically if the gem isn't installed — no errors, just a missing capability.

### Text Loader

```ruby
loader = Ask::RAG::Loader::Text.new
docs = loader.load("notes.txt")
# => [Ask::Document(content: "...", metadata: { source: "notes.txt" })]
```

### Markdown Loader

```ruby
loader = Ask::RAG::Loader::Markdown.new
docs = loader.load("documentation.md")
# Each .md file becomes one document
# metadata[:format] is "markdown"
```

### CSV Loader

```ruby
# All columns become content
loader = Ask::RAG::Loader::CSV.new
docs = loader.load("data.csv")
# One document per row, all fields joined with newlines

# Only specific columns become content
loader = Ask::RAG::Loader::CSV.new(content_columns: %w[title body])
docs = loader.load("articles.csv")

# Separate metadata columns
loader = Ask::RAG::Loader::CSV.new(
  content_columns: %w[body],
  metadata_columns: %w[author date]
)
docs = loader.load("posts.csv")
docs.first.metadata  # => { source: "posts.csv", author: "Alice", date: "2026-01-01" }
```

### JSON Loader

```ruby
# Array of objects — one document per object
loader = Ask::RAG::Loader::JSON.new(content_key: "body")
docs = loader.load("articles.json")
# Each object's "body" field becomes content
# All other fields become metadata

# With explicit metadata keys
loader = Ask::RAG::Loader::JSON.new(
  content_key: "content",
  metadata_keys: %w[title date]
)
docs = loader.load("posts.json")
docs.first.metadata  # => { source: "posts.json", title: "Hello", date: "2026-01-01" }
```

### HTML Loader

Requires `nokogiri`. Strips `<script>`, `<style>`, `<nav>`, `<footer>`, and `<header>` elements by default.

```ruby
loader = Ask::RAG::Loader::HTML.new
docs = loader.load("page.html")

# Customize elements to remove
loader = Ask::RAG::Loader::HTML.new(
  elements_to_remove: %w[script style nav footer header aside]
)
```

### PDF Loader

Requires `pdf-reader`. Produces one document per page.

```ruby
loader = Ask::RAG::Loader::PDF.new
docs = loader.load("manual.pdf")
docs.length       # => number of pages
docs[0].metadata  # => { source: "manual.pdf", page: 1, format: "pdf" }
```

### Directory Loader

Auto-detects file types by extension and dispatches to the appropriate loader. Skips `.git`, `node_modules`, `.svn`, and other non-source directories by default.

<!-- docs-example: not-verified -->
```ruby
loader = Ask::RAG::Loader::Directory.new
docs = loader.load("path/to/docs/")
# Loads all .md, .txt, .html, .csv, .json, .pdf files recursively

# With glob pattern — only Markdown files
loader = Ask::RAG::Loader::Directory.new(pattern: "**/*.md")
docs = loader.load("docs/")

# Custom skip directories
loader = Ask::RAG::Loader::Directory.new(
  skip_dirs: %w[.git node_modules vendor tmp]
)
```

### Lazy Loading

All loaders support lazy enumeration via `lazy_load`:

```ruby
loader = Ask::RAG::Loader::Text.new
loader.lazy_load("big_file.txt").each do |doc|
  # Process one document at a time — no need to hold all in memory
end
```

---

## Text Splitters

Splitters break large documents into smaller, semantically coherent chunks. This is essential for RAG because LLMs have context windows — you can only fit so much text in a prompt.

### RecursiveCharacter Splitter

The workhorse. Splits text by trying separators in order: `"\n\n"` (paragraphs), `"\n"` (lines), `". "` (sentences), `" "` (words), then characters. Each chunk fits within `chunk_size`.

```ruby
splitter = Ask::RAG::TextSplitter::RecursiveCharacter.new(
  chunk_size: 1000,       # Target chunk size in characters
  chunk_overlap: 200      # Overlap between consecutive chunks
)

# Split raw text
chunks = splitter.split_text(long_text)
# => ["chunk1...", "chunk2...", ...]

# Split documents (preserves metadata)
doc = Ask::Document.new(content: long_text, metadata: { source: "doc.md" })
chunks = splitter.split_documents([doc])
# => [Document(content: "chunk0...", metadata: { source: "doc.md", chunk: 0 }), ...]
```

**When to use it:** General-purpose text, articles, documentation, any prose.

### Markdown Splitter

Splits by markdown headers (`#`, `##`, `###`, etc.) and preserves the header hierarchy.

```ruby
splitter = Ask::RAG::TextSplitter::Markdown.new
chunks = splitter.split_text(markdown_content)
# Each chunk starts at a header and includes all content
# until the next header at the same or higher level
```

**When to use it:** Documentation, README files, wiki pages — anything with headers.

### Custom Splitters

Subclass `Ask::RAG::TextSplitter::Base` and implement `split_text(text)`:

```ruby
class SentenceSplitter < Ask::RAG::TextSplitter::Base
  def split_text(text)
    text.split(/(?<=[.!?])\s+/).each_slice(3).map { |s| s.join(" ") }
  end
end
```

---

## Vector Stores

Vector stores hold document embeddings and provide similarity search. When you add documents, they're embedded using an LLM provider's embedding model. When you search, your query is embedded the same way and compared against stored vectors.

### InMemory (Built-in)

Pure Ruby, zero dependencies. Uses cosine similarity. Perfect for development, testing, and small-scale prototypes.

```ruby
store = Ask::RAG::VectorStore::InMemory.new

# Add documents (embeds them using ask-llm-providers)
store.add(chunks, model: "text-embedding-3-small")

# Search
results = store.similarity_search("How do I configure auth?", limit: 5)
```

**Pros:** No database needed, works immediately, thread-safe.
**Cons:** All data is lost on process restart, slow for >10,000 documents.

### PGVector (PostgreSQL)

Production-grade vector store using PostgreSQL's `pgvector` extension. Requires the `pgvector` gem and ActiveRecord.

```ruby
# Migration first:
#   create_table :embeddings do |t|
#     t.text :content
#     t.jsonb :metadata
#     t.vector :embedding, limit: 1536
#   end
#   add_index :embeddings, :embedding, using: :ivfflat, opclass: :vector_cosine_ops

store = Ask::RAG::VectorStore::PGVector.new(
  table_name: :embeddings,
  embedding_column: :embedding
)

store.add(chunks, model: "text-embedding-3-small")
results = store.similarity_search("query", limit: 5)
```

The PGVector adapter auto-loads when the `pgvector` gem is installed. If the gem isn't available, the adapter is skipped silently.

### Similarity Search Options

All vector stores support these search parameters:

```ruby
# Basic search
results = store.similarity_search("query text")

# Limit results
results = store.similarity_search("query", limit: 3)

# Metadata filtering — only return documents whose metadata matches
results = store.similarity_search(
  "query",
  filter: { source: "api_docs.md", version: "2.0" }
)

# MMR (Max Marginal Relevance) — diversify results
results = store.similarity_search(
  "query",
  limit: 5,
  mmr: true,
  diversity_bonus: 0.3
)
# With MMR, results include both :score and :mmr_score in metadata
```

### Search by Vector

If you've already embedded the query yourself, use `similarity_search_by_vector`:

```ruby
results = store.similarity_search_by_vector(
  [0.1, 0.2, 0.3, ...],  # pre-computed query vector
  limit: 5,
  filter: { category: "ruby" }
)
```

### How Scores Work

Search results have their similarity score in `metadata[:score]`:

```ruby
results = store.similarity_search("authentication")
results.first.metadata[:score]  # => 0.923
```

Scores range from -1 to 1 for cosine similarity. Higher values mean more similar.

---

## High-Level RAG Query

The `Ask::RAG::Query.query` method combines retrieval and generation in one call — it searches the vector store, builds a prompt with the retrieved context, and asks an LLM for an answer.

```ruby
answer = Ask::RAG::Query.query(
  store: store,
  question: "What is the default timeout configuration?",
  model: "gpt-4o"           # LLM model to answer with
)

puts answer.content            # The LLM's answer
puts answer.metadata[:sources] # ["config.md", "settings.md"]
puts answer.metadata[:model]   # "gpt-4o"
```

If the store has no relevant documents, `query` returns `nil` — the LLM is never called.

---

## Complete Example: Documentation Q&A Bot

<!-- docs-example: not-verified -->
```ruby
require "ask-rag"

# Index phase — run once
puts "Indexing documentation..."
store = Ask::RAG::VectorStore::InMemory.new

loader = Ask::RAG::Loader::Directory.new(pattern: "**/*.md")
splitter = Ask::RAG::TextSplitter::RecursiveCharacter.new(
  chunk_size: 1000,
  chunk_overlap: 200
)

docs = splitter.split_documents(loader.load("docs/"))
puts "Indexed #{store.add(docs, model: "text-embedding-3-small").length} chunks"
puts "Done indexing. Ready for questions."

# Query phase — run for each user question
loop do
  print "\nAsk a question (or 'quit'): "
  question = gets.chomp
  break if question == "quit"

  answer = Ask::RAG::Query.query(
    store: store,
    question: question,
    model: "gpt-4o",
    limit: 3
  )

  if answer
    puts "\n#{answer.content}"
    puts "\nSources: #{answer.metadata[:sources].join(', ')}"
  else
    puts "\nNo relevant documents found."
  end
end
```

---

## Integration with ask-agent

Use ask-rag as a tool inside an ask-agent session:

<!-- docs-example: not-verified -->
```ruby
require "ask-rag"
require "ask-agent"

# Set up your vector store (run once)
store = Ask::RAG::VectorStore::InMemory.new
loader = Ask::RAG::Loader::Markdown.new
splitter = Ask::RAG::TextSplitter::RecursiveCharacter.new
chunks = splitter.split_documents(loader.load("docs/"))
store.add(chunks, model: "text-embedding-3-small")

# Define a search tool your agent can use
class SearchDocs < Ask::Tool
  description "Search documentation for relevant information"
  param :query, type: :string, desc: "Search query"

  def execute(query:)
    store.similarity_search(query, limit: 3).map do |doc|
      { content: doc.content[0..500], score: doc.metadata[:score] }
    end
  end
end

# Now your agent can search docs automatically
session = Ask::Agent::Session.new(
  model: "gpt-4o",
  tools: [SearchDocs]
)
session.run("How do I configure authentication?")
```

---

## Design Notes

### Why Documents?

A document is the universal currency of the RAG pipeline. Every step transforms documents:

1. **Load** — a file becomes one or more documents
2. **Split** — one document becomes many smaller documents (chunks)
3. **Embed** — document content is converted to a vector (the document object is stored alongside)
4. **Search** — a query returns documents ranked by similarity

Without a document abstraction, every step would need its own data type and pipeline composition would require glue code.

### Why Separate Documents from Vectors?

Documents and vectors have different lifetimes:

- A **document** changes when its content is edited
- A **vector** changes when the embedding model changes

If you store documents inside the vector store, migrating to a new embedding model means re-inserting everything — even the text hasn't changed. With decoupled documents, you just re-embed and update the vector column.

Documents are also human-readable and debuggable. Vectors are opaque arrays of floats.

### Embedding Model Tracking

Both InMemory and PGVector stores track which embedding model was used during `add()`. When you call `similarity_search()`, the same model is used for query embedding — no dimension mismatches.

If an embedding call fails, `Ask::RAG::EmbeddingError` is raised with a clear message rather than silently returning a zero vector.

---

## Installation

```ruby
# Gemfile
gem "ask-rag"

# Optional: for HTML loading
gem "nokogiri"

# Optional: for PDF loading
gem "pdf-reader"

# Optional: for PostgreSQL vector storage
gem "pgvector"
```

---

## Next Steps

- [Explore all core components](/ask-docs/core)
- [Build custom tools](/ask-docs/extending/custom-tools)
