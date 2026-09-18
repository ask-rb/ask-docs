---
layout: default
title: Decisions
parent: Core Components
nav_order: 18
---

# Decisions

LLMs generate text. Deciders decide. ask-decisions asks a System One model
(Jev) structured questions — classify this, score that, is this yes or no —
and gets typed answers with calibrated probabilities back. No prose to parse,
no "the answer is probably" to regex out of a completion.

**Use ask-decisions when** the answer is a choice from a closed set: which
lane does this message belong to, how urgent is this, does this command look
destructive, should this tool result still be in the conversation. Anything
expressible as a closed set becomes a decision. Anything that must produce
new text stays a generation.

**Use ask-llm-providers when** you want the model to write. The two compose:
Jev decides what to do, the LLM does it.

## Installation

```ruby
gem "ask-decisions"
```

```ruby
require "ask-decisions"
```

The only hard dependency is `ask-core`. The TypeSafe provider needs a
`TYPESAFE_API_KEY`; the Static provider needs nothing and exists for tests.

## How a decision works

Every call has the same shape: a **state** (what Jev should look at) and a
set of **questions** (what you want to know about it). The answers come back
typed — a choice with calibrated confidence, a score on the spectrum you
defined, a probability for a yes/no.

```ruby
require "ask-decisions"

result = Ask.decide(
  state: "Help! My payouts have been failing for 3 days.",
  decisions: {
    "route" => Ask::Decision::Choice.new(
      instructions: "Which team should handle this?",
      criteria: { billing: "Payment issues", technical: "Bugs", sales: "Pricing" }
    ),
    "urgent" => Ask::Decision::Noul.new(instructions: "Does this convey urgency?")
  },
  provider: :static
)

result["route"].choice   # => :billing
result["route"].confidence  # => 1.0
result["urgent"].noul    # => 0.5
```

(This and every other example on this page runs against the Static provider
— canned answers, no network. Swap `:static` for `:typesafe` and the same
code asks Jev for real.)

The state is the one place judgment happens. Everything irrelevant in it is
a chance to misread what is relevant, so keep it to what the questions
actually need — a message, a command, a tool output. Longer state has been
measured to make Jev worse, not better.

## The three question types

Three question types, three answer types. That is the whole vocabulary.

| Type | Ask it when | Answer |
|---|---|---|
| **Choice** | The answer is one of a known set | `.choice`, `.confidence`, `.probabilities` |
| **Score** | The answer is a point on a spectrum | `.score`, `.legend`, `.confidence` |
| **Noul** | The answer is yes or no | `.noul` (0–1), `.yes?`, `.strength` |

```ruby
require "ask-decisions"

route = Ask::Decision::Choice.new(
  instructions: "Which team should handle this?",
  criteria: { billing: "Payment issues", technical: "Bugs", none: "None of these" }
)

urgency = Ask::Decision::Score.new(
  instructions: "How urgent is this?",
  criteria: ["Not urgent", "Somewhat urgent", "Very urgent"]
)

urgent = Ask::Decision::Noul.new(instructions: "Does this convey urgency?")
```

Two habits worth picking up on day one:

**Give every Choice a way out.** A choice with no `none`/`other` option
forces the model to pick a wrong answer when none fits. `Ask::Decisions::Lint`
catches this and six other anti-patterns before a question ever reaches the
API.

**Say what each option means.** The criteria values are not labels, they are
the definitions Jev sorts against. `"billing" => "Payment issues"` is a
definition; `"billing" => "Billing"` is a tautology.

## Reading answers

Choice and Score answers carry calibrated confidence — the model's own
estimate of how sure it is, measured against reliability curves you can run
yourself (see [Calibration](#calibration-trust-but-measure)). Noul answers
carry a probability and no separate confidence; the distance from 0.5 is the
strength.

```ruby
require "ask-decisions"

provider = Ask::Decisions::Static.new(answers: {
  "route" => Ask::DecisionResult::ChoiceAnswer.new(
    id: "route", choice: "technical",
    probabilities: { "technical" => 0.86, "billing" => 0.10, "none" => 0.04 },
    confidence: 0.86
  )
})

result = Ask.decide(
  state: "bundle exec rake test fails with NoMethodError",
  decisions: { "route" => Ask::Decision::Choice.new(
    instructions: "Which team?",
    criteria: { billing: "Payment issues", technical: "Bugs", none: "None of these" }
  ) },
  provider: provider
)

result["route"].choice         # => :billing
result["route"].confidence     # => 1.0
result["route"].confident?(0.7)  # => true
```

The threshold is yours to set per call site. `confident?(0.7)` is the
question "am I willing to be wrong 30% of the time here?" — the answer
differs between routing a support ticket and approving a `rm -rf`.

## Batch every question

Jev evaluates all questions in one request in parallel; adding questions
barely changes latency or cost. So the discipline is: send every question the
turn might need, let Ruby ignore the answers it doesn't reach.

```ruby
require "ask-decisions"

result = Ask::Decisions.batch(state: "Server is down, customers are calling") do |b|
  b.ask("route", Ask::Decision::Choice.new(
    instructions: "Which team?",
    criteria: { billing: "Payments", technical: "Bugs", none: "Neither" }
  ))
  b.ask("urgent", Ask::Decision::Noul.new(instructions: "Does this convey urgency?"))
  b.ask("tone", Ask::Decision::Score.new(
    instructions: "How does the writer sound?",
    criteria: ["Upset", "Neutral", "Pleased"]
  ))
end
# One API call, three answers.
result["urgent"].noul  # => 0.5
```

This is why the higher-level components below bundle their questions: the
Gate asks four risk questions in one request, the OutputJudge two, Triage
three. Asking more costs no extra latency, so a guard that checks one more
thing is free.

## The four verbs

Everything Jev does with LLMs falls into one of four patterns. Knowing which
one you want tells you where the decision belongs in your pipeline.

| Verb | Shape | Example |
|---|---|---|
| **Route** | decide → generate | Jev picks the lane; the LLM writes the answer |
| **Filter** | generate → decide | The LLM proposes facts; Jev keeps the good ones |
| **Replace** | decide, no generate | Triage, scoring, relevance — no text needed |
| **Guard** | decide ⟶ gate generate | Screen input/output; gate actions on confidence |

## Guards: Gate and OutputJudge

Agents run tools. Two guards belong around every side-effecting tool: one
before the call, one after.

### Gate — before the call

The Gate judges intent before a tool executes. Four calibrated questions in
one request: is this destructive, does it exfiltrate data, does it go beyond
scope, how much damage if unwanted.

```ruby
require "ask-decisions"

provider = Ask::Decisions::Static.new(answers: {
  "destructive"  => Ask::DecisionResult::NoulAnswer.new(id: "destructive", noul: 0.99),
  "exfiltration" => Ask::DecisionResult::NoulAnswer.new(id: "exfiltration", noul: 0.04),
  "beyond_scope" => Ask::DecisionResult::NoulAnswer.new(id: "beyond_scope", noul: 0.98),
  "impact" => Ask::DecisionResult::ScoreAnswer.new(
    id: "impact", score: 3.0,
    legend: { "0" => "No damage", "1" => "Minor", "2" => "Moderate", "3" => "Severe" },
    probabilities: { "3" => 1.0 }, confidence: 0.99
  )
})

gate = Ask::Decisions::Gate.new(provider)
verdict = gate.judge(
  tool: "bash",
  args: { command: "rm -rf src && git push --force origin main" },
  user_message: "clean up the old code"
)

verdict.passed?   # => false
verdict.flagged   # => [:destructive, :beyond_scope, :impact]
```

The default questions are written for a coding agent's shell tool. For your
own tools, say what risk means for them — a booking tool's question is
"does this commit the customer to an appointment?", not "is this
destructive?". Pass `questions:` and `thresholds:` to the constructor; every
question must be armed with a threshold, and a question without one is
refused at construction rather than silently ignored.

### OutputJudge — after the call

The OutputJudge screens what came back: does the output contain a secret,
and what kind of failure was this. Both answers in one request, ~100ms.

```ruby
require "ask-decisions"

provider = Ask::Decisions::Static.new(answers: {
  "leaks_secret" => Ask::DecisionResult::NoulAnswer.new(id: "leaks_secret", noul: 0.01),
  "failure_class" => Ask::DecisionResult::ChoiceAnswer.new(
    id: "failure_class", choice: "transient",
    probabilities: { "transient" => 0.92 }, confidence: 0.92
  )
})

judge = Ask::Decisions::OutputJudge.new(provider)
result = judge.judge(tool: "bash", output: "npm ERR! code ECONNRESET", args: { command: "npm test" })

result.leak?          # => false
result.failure_class  # => "transient"
result.advice         # => "Retry unchanged."
```

The failure classes carry advice because the point is what to do next:
`transient` retries unchanged, `code_bug` means the code must change,
`environment` means fix the machine first. Screen the output once and the
retry policy writes itself.

## Triage: one read, every answer

An inbound message usually needs three things known about it before anything
happens: which lane it belongs to, how the person sounds, and whether they
want a human. Triage asks all three in one request, because the questions
are independent and the call costs the same either way.

```ruby
require "ask-decisions"

provider = Ask::Decisions::Static.new(answers: {
  "lane" => Ask::DecisionResult::ChoiceAnswer.new(
    id: "lane", choice: "knowledge",
    probabilities: { "knowledge" => 1.0 }, confidence: 1.0
  ),
  "sentiment" => Ask::DecisionResult::ScoreAnswer.new(
    id: "sentiment", score: 1.0,
    legend: { "0" => "Upset or angry", "1" => "Neutral", "2" => "Warm or pleased" },
    probabilities: { "1" => 1.0 }, confidence: 0.9
  ),
  "wants_human" => Ask::DecisionResult::NoulAnswer.new(id: "wants_human", noul: 0.02)
})

triage = Ask::Decisions::Triage.new(provider, lanes: {
  "knowledge" => "Asks about the business, its services, prices, hours, or policies",
  "booking"   => "Wants to book an appointment or asks what times are free",
  "human"     => "Wants to speak to a person, or describes an emergency",
  "close"     => "Says goodbye or is done",
  "chat"      => "Small talk or a greeting needing no action",
  "unclear"   => "None of these is clear; a clarifying question is needed first"
})

verdict = triage.read(message: "What time do you close on Saturdays?")

verdict.lane            # => "knowledge"
verdict.certain?(0.7)   # => true
verdict.sentiment       # => 1.0
verdict.wants_human?    # => false
```

### Lanes, not tools

Route to a **lane**, then let code map the lane to its tools. Measured on a
19-tool roster, same model, same messages:

| Routed to | Correct |
|---|---|
| one of the 19 tools | 10/16 |
| one of 6 lanes | **19/20** |

The reason is structural, not a tuning problem. Seven of those tools all
answer from the same knowledge base, and which one holds the answer is
discovered by *calling* them, not by reading the message. Routing straight
to a tool asks a question the message does not carry, so a router that
answers it is guessing with confidence.

A reading should narrow, never grant: let the lane take tools away from a
turn, and let the agent's own definition stay the ceiling.

## Acting on confidence: ConfidencePolicy

High confidence acts, middle confidence asks a human, low confidence
escalates. The thresholds are per-tool because a read-only lookup and a
payment are not dangerous for the same reason.

```ruby
require "ask-decisions"

policy = Ask::Decisions::ConfidencePolicy.new
policy.add_rule("search", risk: :low)
policy.add_rule("refund", risk: :high)

policy.evaluate(tool: "search", confidence: 0.6).action  # => :act
policy.evaluate(tool: "refund", confidence: 0.8).action  # => :review
```

## Compaction: pruning instead of summarizing

{: .new }
> New in ask-decisions 0.2.3

Every agent that runs long enough hits the same wall: the conversation
outgrows the context window. The usual fix is to ask an LLM to summarize the
old turns. A summary is lossy by design — a file path, an exact error, a
constraint the user stated once ("never edit src/generated") — any of these
can vanish even when it matters three hours later.

The Compactor takes a different trade. It never rewrites anything. It asks
Jev to score every tool call and result in the conversation — one fast
request, batched — and then:

| Jev says | The compactor does |
|---|---|
| result still needed | Keeps the call and result **verbatim** |
| call matters, result doesn't | Keeps the call, truncates the result to a short head |
| neither matters | Removes both |

User and assistant text is never touched. What survives is the original
conversation, minus the tool traffic Jev says no longer matters. In
practice that is most of it — a long coding session is mostly `ls` output,
file dumps, and git status that mattered once and never again. Scoring the
calls instead of summarizing the text is what took a ~1M-token session down
to 86K in about a second, with nothing rewritten.

```ruby
require "ask-decisions"

provider = Ask::Decisions::Static.new(answers: {
  "keep_call_read_spec" => Ask::DecisionResult::NoulAnswer.new(id: "keep_call_read_spec", noul: 0.9),
  "keep_result_read_spec" => Ask::DecisionResult::NoulAnswer.new(id: "keep_result_read_spec", noul: 0.9),
  "keep_call_ls" => Ask::DecisionResult::NoulAnswer.new(id: "keep_call_ls", noul: 0.1),
  "keep_result_ls" => Ask::DecisionResult::NoulAnswer.new(id: "keep_result_ls", noul: 0.1)
})

messages = [
  { role: "user", content: "Fix the failing test in user_spec.rb" },
  { role: "assistant", tool_calls: [{ id: "read_spec", name: "Read", input: { path: "spec/user_spec.rb" } }] },
  { role: "tool", tool_call_id: "read_spec", content: "it 'validates email' do ... end" },
  { role: "assistant", tool_calls: [{ id: "ls", name: "Bash", input: { command: "ls -R" } }] },
  { role: "tool", tool_call_id: "ls", content: "app/\nbin/\nconfig/\nspec/\ntmp/ … 400 more lines" },
  { role: "assistant", content: "The spec expects email validation. Checking the model." },
  { role: "assistant", content: "One line fixes it." }
]

compactor = Ask::Decisions::Compactor.new(provider, preserve_recent: 2)
result = compactor.compact(messages)

result.messages.length   # => 5
result.stats[:dropped]   # => 1
result.stats[:kept]      # => 1
result.compacted?        # => true
```

The `ls` pair is gone — both messages. The `Read` pair is exactly as it was.
The user's instruction and the assistant's text never entered a decision at
all.

### Pinned messages

Two zones are never touched: the first message (it usually carries the task)
and the most recent `preserve_recent:` messages (they are what the next turn
builds on). A pair living entirely in a pinned zone is not even scored —
Jev never sees it. A pair straddling the boundary is scored, but a pinned
message is never removed and a result is never left without its call: a
"drop" that touches a pinned message downgrades to keeping the call and, at
most, truncating the result.

### Reading the stats

```ruby
require "ask-decisions"

compactor = Ask::Decisions::Compactor.new(Ask::Decisions::Static.new)
result = compactor.compact([
  { role: "user", content: "Start" },
  { role: "assistant", tool_calls: [{ id: "c1", name: "Bash", input: {} }] },
  { role: "tool", tool_call_id: "c1", content: "listing" },
  { role: "user", content: "a" },
  { role: "user", content: "b" },
  { role: "user", content: "c" },
  { role: "assistant", content: "Done" }
])

result.stats[:messages_before]  # => 7
result.stats[:messages_after]   # => 7
result.stats[:kept]             # => 1
result.stats[:reduction_ratio]  # => 0.0
result.to_s                     # => "no compaction needed (7 messages)"
```

With the default Static answers (noul 0.5) and the default threshold (0.5),
everything keeps — which makes `keep_threshold:` the knob that trades
fidelity for size. Raise it toward 0.9 to prune only what Jev is sure
about; lower it when the window is the binding constraint.

### Wiring it into ask-agent

[The Agent Loop](/ask-docs/core/agent) summarizes old turns when the window
fills; [Custom Agents](/ask-docs/extending/custom-agents) shows the seam for
replacing that behavior. The decisions layer builds the same trade on
calibrated scores instead of a summary:

```ruby
require "ask-decisions"

adapter = Ask::Decisions::AgentAdapter.new(:typesafe)
compactor = adapter.build_compactor(preserve_recent: 6)

# result = compactor.compact(session.messages)
# session.messages.replace(result.messages)
```

Fail open: if the decision call raises — no key, rate limit, timeout — keep
the original transcript and fall back to the built-in summary. A compaction
that does not happen this turn happens next turn; a lost constraint is gone
for good.

### When to reach for it

Reach for the Compactor when sessions run long and the old turns are mostly
tool traffic — coding agents, research runs, anything that reads many files.
Reach for summarization when the old turns are mostly prose whose gist is
the point and whose details never were. The two also compose: prune the
tool noise with decisions, summarize the remainder if you must.

## Swapping providers

The provider registry makes Jev swappable — same questions, different
decider:

```ruby
# Production: Jev
Ask::Decisions.configure { |c| c.default_provider = :typesafe }

# Tests: canned answers, no network
Ask::Decisions.configure { |c| c.default_provider = :static }

# Tomorrow: register another decider
Ask::DecisionProvider.register(:openjev, MyProvider)
Ask::Decisions.configure { |c| c.default_provider = :openjev }
```

Every example on this page passes its provider explicitly; the global
default is there so application code can stay provider-agnostic.

## Calibration: trust, but measure

Confidence is only useful if it is honest. The calibration harness runs your
real decisions through the provider N times and reports reliability curves —
does "86% confident" actually mean right 86% of the time?

```ruby
harness = Ask::Decisions::CalibrationHarness.new(provider)
harness.add_case(
  id: "urgent_ticket",
  state: "Help! Server down!",
  decisions: { "urgent" => Ask::Decision::Noul.new(instructions: "Is this urgent?") },
  expected: { "urgent" => { noul_above: 0.7 } },
  runs: 10
)
report = harness.run
puts report  # reliability curve per decision id, accuracy by confidence band
```

Run this before trusting a threshold in production, and again whenever you
change a question's wording. The questions are cheap; being wrong at scale
is not.

## Lint: catch bad questions early

Questions have anti-patterns — a Choice with no way out, instructions that
narrate a reasoning path ("first check A, then B..."), thresholds no one
armed. Lint checks a question set before it reaches the API:

```ruby
require "ask-decisions"

warnings = Ask::Decisions::Lint.check({
  "good" => Ask::Decision::Noul.new(instructions: "Is this urgent?"),
  "bad" => Ask::Decision::Choice.new(
    instructions: "Which team? Since this cannot be recovered...",
    criteria: { a: "A", b: "B" }
  )
})
warnings.length  # => 2
warnings.first   # => "bad: instructions contain a reasoning path or justification clause. Ask the
# plain property instead — measured to reduce accuracy."
```

## Configuration

```ruby
Ask::Decisions.configure do |c|
  c.default_provider = :typesafe   # :static for tests
  c.default_model    = "jev-latest"
  c.api_key          = ENV["TYPESAFE_API_KEY"]  # or ask-auth resolution
  c.api_base         = nil        # proxy / gateway override
  c.timeout          = 5.0
end
```

`Ask.decide(state:, decisions:)` resolves the configured default provider;
per-call `provider:` overrides it.

## Next steps

- [The Agent Loop](/ask-docs/core/agent) — the summarization compactor this
  one can replace, and the guard hooks the AgentAdapter wires into
- [Custom Agents](/ask-docs/extending/custom-agents) — the compaction seam
- [Evaluating LLM Outputs](/ask-docs/production/evaluation) — where the
  calibration mindset comes from
- [ask-decisions on GitHub](https://github.com/ask-rb/ask-decisions) — the
  README carries the API reference for every component
