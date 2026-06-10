---
layout: default
title: ask-eval
parent: ask-core
nav_order: 50
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
| Judge model | **Any model as judge** — cheap gpt-4o-mini, accurate claude, or local |
| Cost tracking | **Per evaluation** — token and cost tracking |
| Test framework | **Minitest plugin** — auto-loads with `require "ask/eval/minitest"` |

## Quick Start

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
- A **model string** (e.g., `"openai/gpt-4o-mini"` — resolves via `Ask::ModelCatalog`)

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
| **v0.1.0** | Deterministic + Faithful/Hallucination/Bias/Toxicity/Correctness judges + Minitest DSL + custom judges + CI reporters (JUnit, GitHub) + cost tracking. No future versions planned — everything core is here. |
