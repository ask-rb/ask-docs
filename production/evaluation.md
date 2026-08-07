---
layout: default
title: Evaluating LLM Outputs
parent: Production
nav_order: 4
---


# ask-eval

**LLM evaluation for Ruby — Minitest-native assertions.** Test LLM outputs the same way you test everything else — with assertions in your existing test suite.

```ruby
gem "ask-eval"
```

## Design Philosophy

No standalone evaluator. No new workflow. No separate config file. Just `assert_faithful response, context: docs` in your Minitest test.

| Feature | ask-eval |
|---------|----------|
| Integration | **Minitest-native assertions** — drops into existing tests |
| Judges | **5 essential judges** — faithful, hallucination, bias, toxicity, correctness |
| Reporters | **3 reporters** — console (dev), JUnit (CI), GitHub Actions (annotations) |
| Judge model | **Any model as judge** — cheap deepseek-v4-flash, accurate claude, or local |
| Cost tracking | **Per evaluation** — token and cost tracking |
| Test framework | **Minitest plugin** — auto-loads with `require "ask/eval/minitest"` |

## Quick Start

<!-- docs-example: not-verified -->
```ruby
require "ask/eval"
require "ask/eval/dsl"

class MyEvalTest < Minitest::Test
  include Ask::Eval::DSL

  test "response is faithful to context" do
    response = my_rag_app.query("What's the return policy?")
    assert_faithful response, context: [my_docs]
  end

  test "response contains expected info" do
    response = my_app.generate_email("Order confirmation")
    assert_contains response, "Thank you for your order"
    assert_regex response, /order #\d{5}/
  end
end
```

## Deterministic Assertions

Synchronous checks that need no LLM:

```ruby
assert_contains output, "substring"
assert_not_contains output, "bad word"
assert_regex output, /pattern/
assert_json output                     # valid JSON?
assert_max_tokens output, 500
assert_starts_with output, "Hello"
assert_ends_with output, "Goodbye"
assert_equals output, "exact string"
assert_min_length output, 10
assert_max_length output, 500
assert_url output
assert_email output
```

## LLM-as-Judge Assertions

Each judge evaluates an LLM output and returns a verdict with score (0.0–1.0) and reasoning:

```ruby
assert_faithful response, context: docs        # faithful to source context?
assert_not_hallucinating response, context: docs # made-up info not in context?
refute_bias response                            # no demographic or other bias?
refute_toxicity response                        # no toxic or harmful language?
assert_correctness response, expected: expected  # matches expected output?
```

### Judge Model

Each assertion accepts a `model:` parameter. The model can be:

- A **callable** (lambda/proc) — ideal for testing
- An **Ask::Provider** instance (e.g., `Ask::Providers::OpenAI.new`)
- A **model string** (e.g., `"openai/deepseek-v4-flash"` — resolves via `Ask::ModelCatalog`)

Configure a default judge globally:

```ruby
Ask::Eval.configure do |c|
  c.default_judge = model
end
```

### Testing with a lambda

```ruby
require "json"

model = ->(messages) {
  { content: JSON.generate({ passed: true, score: 0.95, reason: "OK" }) }
}
assert_faithful response, context: docs, model: model
```

## Minitest Plugin

For automatic inclusion in all Minitest tests, add to your test helper:

# not-verified
<!-- docs-example: not-verified -->
```ruby
# test/test_helper.rb
require "ask/eval/minitest"
```

Now every `Minitest::Test` has access to `assert_faithful`, `assert_contains`, `refute_bias`, etc. without manually including the DSL module.

## Core Types

```ruby
Ask::Eval::TestCase = Data.define(:input, :actual_output, :expected_output, :context)
```

Construct with keyword arguments:

```ruby
TestCase.new(
  input: "What's 2+2?",
  actual_output: "4",
  expected_output: "4",
  context: "Math facts"
)
```

## Batch Runner

Run evaluations outside of Minitest:

```ruby
runner = Ask::Eval::Runner.new
runner.test("My Test", output: "hello world 123") do |r|
  r.assert(:faithful, context: docs)
  r.assert(:contains, value: "hello")
  r.assert(:regex, pattern: /\d+/)
end
results = runner.run
summary = runner.summary
# => { total: 3, passed: 2, failed: 1, results: [...] }
```

## Datasets & Experiment Runs (v0.4.0+)

{: .new }
> New in ask-eval 0.4.0

The A/B-testing loop for agents. Pin a fixed set of inputs, run them
against a variant (a changed prompt, a different model), and compare —
like fixtures, except the items are prompts/tasks fed to a live agent, and
the point is diffing how different configurations perform:

<!-- docs-example: not-verified -->
```ruby
require "ask-eval"

# Pin the inputs once (persistable to JSON like fixtures)
dataset = Ask::Eval::Dataset.new("support-cases")
dataset.add(input: "The API returns 401 on stale tokens — how do I fix my auth flow?",
            expected: "Rotate the token, then retry", tags: ["auth"])
dataset.add(input: "Summarize this thread and suggest next steps", tags: ["support"])
dataset.save("support-cases.json")
# dataset = Ask::Eval::Dataset.load("support-cases.json")

# Run the same dataset against two variants of your agent
run_a = dataset.experiment(
  runner: ->(input) { agent(input, system_prompt: OLD_PROMPT) },
  scorer: ->(input:, output:, expected:) { output == expected ? 1.0 : 0.0 }
).run
run_b = dataset.experiment(
  runner: ->(input) { agent(input, system_prompt: NEW_PROMPT) },
  scorer: ->(input:, output:, expected:) { output == expected ? 1.0 : 0.0 }
).run

run_a.summary
# => { total: 2, passed: 1, failed: 1, avg_score: 0.5, total_duration_ms: 1234 }

run_a.compare(run_b)
# => { deltas: [{ item_id:, input:, a: {output:, score:}, b: {...}, delta: 0.5 }],
#      a: summary, b: summary, verdict: "b" }   # "a" | "b" | "tie"
```

- **Dataset items** carry `input` (required), plus optional `expected`
  output, `context`, `tags`, and `metadata`. `Dataset.save` / `Dataset.load`
  persist to JSON files.
- **Experiments** run every item through a `runner:` callable (input →
  output); runner errors are captured per item and the run continues. The
  optional `scorer:` callable receives `(input:, output:, expected:)` and
  returns a 0..1 score.
- **`compare`** matches items by id across runs, so partial overlaps still
  compare; the verdict is the higher average score ("tie" when equal).
- Bring your own agent wiring in the runner — ask-eval stays decoupled
  from ask-agent.

## CI Integration

### JUnit XML

Works with Jenkins, CircleCI, GitLab CI:

```ruby
xml = Ask::Eval::Reporters::JUnit.new(results).to_xml
File.write("eval-results.xml", xml)
```

### GitHub Actions

Generates `::warning` and `::error` annotations for PRs:

```ruby
reporter = Ask::Eval::Reporters::GitHub.new(results)
reporter.report
```

### Console

Human-readable output for development:

```ruby
Ask::Eval::Reporters::Console.new(results).report
```

## Cost Tracking

Track token usage and costs per evaluation:

```ruby
Ask::Eval.configure do |c|
  c.track_cost = true
end

# Access accumulated costs
report = Ask::Eval.cost_report
# => { total_cost: 0.00015, total_calls: 2, by_judge: { ... } }
```

Cost tracking uses built-in pricing estimates for common models (GPT-4o-mini, Claude Sonnet, Gemini, etc.) and falls back to a default pricing model for unknown models.

## Assertion Runner

The `Assertions.evaluate` method routes assertions by name:

```ruby
Ask::Eval::Assertions.evaluate(:contains, output, value: "hello")
Ask::Eval::Assertions.evaluate(:faithful, output, context: docs)
```

Batch evaluate multiple assertions:

```ruby
tc = Ask::Eval::TestCase.new(actual_output: output, context: docs)
results = Ask::Eval::Assertions.evaluate_all(tc, [
  { name: :contains, value: "hello" },
  { name: :faithful }
])
```


## Agent Session Evaluation

{: .new }
> New in ask-eval 0.2.0

Test a full agent session, not just a single output. `Ask::Eval::SessionEval` wraps an `Ask::Agent::Session` and tracks which tools it called and what it cost:

```ruby
eval = Ask::Eval::SessionEval.new(session)
eval.run("Check server health")
eval.tool_called?("bash")   # => true
eval.total_cost             # => 0.0012
```

The `eval_session` DSL wires this up in a Minitest test with automatic recording:

```ruby
test "health check agent" do
  eval_session(model: "deepseek-v4-flash", tools: [Bash]) do |r|
    r.run("Check health")
    assert_tool_called "bash"
    assert_cost_under 0.01
  end
end
```

## Deterministic CI with Recorded Replays

{: .new }
> New in ask-eval 0.2.0

LLM calls are non-deterministic, which makes CI flaky. `Ask::Eval::Recorder` captures provider interactions to JSON files on the first run, then replays them on demand:

```ruby
recorder = Ask::Eval::Recorder.new(test_name: "my_suite")
recorder.wrap(session)
session.run("Check health")
recorder.save  # test/recordings/my_suite/recording.json
```

Run with `ASK_EVAL_MODE=replay` and the recorder uses the saved responses instead of making real API calls. No network, no cost, deterministic assertions. If no recording exists, it raises with a clear message telling you to run once without the env var first.

## Custom Judges

The 5 built-in judges cover common cases, but you can create your own by
subclassing `Ask::Eval::Judge`:

```ruby
class BrandVoiceJudge < Ask::Eval::Judge
  def call(tc)
    query_judge(tc)
  end

  private

  def system_prompt
    <<~PROMPT
      You are a brand voice evaluator. Determine if the response matches our guidelines.
      Respond in JSON format.
    PROMPT
  end

  def user_message(tc)
    "Response to evaluate: " + tc.actual_output
  end
end

judge = BrandVoiceJudge.new(model: my_model)
result = judge.call(Ask::Eval::TestCase.new(actual_output: response))
```

No registration system needed. Subclassing `Judge` and implementing
`#call`, `#system_prompt`, and `#user_message` is the entire API.

For simple checks, pass a callable as `model:` directly:

```ruby
assert_faithful response, context: docs, model: ->(messages) {
  { content: JSON.generate({ passed: true, score: 1.0, reason: "OK" }) }
}
```


## Dependencies

- **Runtime:** Zero. Deterministic assertions work out of the box.
- **LLM Judge (optional):** When using LLM-as-judge assertions, a judge model is required. Accepts any callable, Ask::Provider instance, or model string.
- **Build/test:** minitest, rake
- **CI (JUnit):** rexml (bundled with Ruby stdlib)

## Release Notes

| Version | Features |
|---------|----------|
| **v0.2.0** | Session evaluation (`SessionEval`, `eval_session`, `assert_tool_called`, `assert_cost_under`) and regression recording/replay (`Recorder`, `ASK_EVAL_MODE=replay`) |
| **v0.1.0** | Deterministic + Faithful/Hallucination/Bias/Toxicity/Correctness judges + Minitest DSL + custom judges + CI reporters (JUnit, GitHub) + cost tracking |
