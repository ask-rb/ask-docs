---
layout: default
title: Workflows & Graphs
parent: Core Components
nav_order: 11
---

# Workflows & Graphs

ask-graph lets you define durable, multi-step workflows with conditional routing, parallel execution, human approval steps, crash recovery, and sub-workflow composition. Each step is a plain Ruby class.

**Use ask-graph when** you need a reliable multi-step process — order fulfillment, document processing pipelines, approval workflows, data ETL. Steps checkpoint after every completion, so a crash mid-way means you resume where you left off, not from the start.

```ruby
gem "ask-graph"
```

## ask-graph vs ask-agent

These two solve different problems, and knowing which one you need saves you a lot of rework.

**ask-agent is an LLM-driven loop.** The model decides what to do next, turn by turn: call this tool, read that file, then answer. Use it for open-ended work where you can't enumerate the steps in advance — chatbots, coding assistants, research agents, anything conversational. Each turn costs tokens, and the path is different every run.

**ask-graph is a deterministic pipeline.** You write every step up front as plain Ruby. The workflow runs the same way every time, checkpoints after each step, and resumes from the last completed step after a crash. Use it for processes with known steps and a business SLA — charge a card, send an email, sync a CRM, generate a report at 9am. No LLM tokens involved unless you put a model call inside a step.

| | ask-agent | ask-graph |
|---|---|---|
| **Decides what to do** | The model, at runtime | You, at write time |
| **Steps** | Emergent, different each run | Fixed, declared up front |
| **Determinism** | None by nature | Fully reproducible |
| **Crash recovery** | Session state saved per turn | Checkpoint per step, resume in place |
| **Cost** | Token-based per turn | Zero unless a step calls an LLM |
| **Good for** | Chatbots, coding assistants, research | Order fulfillment, ETL, approvals, scheduled jobs |

They compose well. A workflow step can call an agent session when a decision needs a model. An agent tool can run a workflow when a task has a known shape. See [Where actions fit](/ask-docs/rails/actions#where-actions-fit) for how agents, workflows, and actions relate in a Rails app.

## Quick Start

```ruby
require "ask-graph"
require "ostruct"

# Steps are plain Ruby classes with a call(context) method
class ValidateOrder
  def call(context)
    context.valid = context.order.valid?
  end
end

class ChargeCustomer
  def call(context) = context.charged = true
end

class SendConfirmation
  def call(context) = context.sent = true
end

class NotifyAdmin
  def call(context) = context.notified = true
end

# Define a workflow
module ProcessOrder
  class Workflow < Ask::Graph
    step ValidateOrder
    step ChargeCustomer,  if: :valid?
    step SendConfirmation, if: :valid?
    step NotifyAdmin,     unless: :valid?

    private

    def valid?
      context.valid
    end
  end
end

# Run it
order = OpenStruct.new(valid?: true)
result = ProcessOrder::Workflow.call({ order: order })
result.order.valid?  # => true
result.charged       # => true
# NotifyAdmin is skipped: the unless: condition is false
result.notified      # => nil
```

The `call` class method creates an instance, runs through all steps, and returns a `Context` object with every step's output accessible by name.

## Defining Steps

Steps are plain Ruby classes with a `call(context)` method. They read from and write to the context — no return values, no special interfaces.

```ruby
class ValidateOrder
  def call(context)
    order = context.input[:order]
    context.order = OrderValidator.validate(order)
    context.valid = context.order.errors.empty?
  end
end
```

When a Hash is passed as input to a workflow, its keys are directly accessible on the context:

```ruby
result = MyWorkflow.call({ order: order })
result.input       # => { order: order }
result.order       # => the order — same as input[:order]
```

This works for all hash inputs, including data passed to sub-workflows.

### The step contract

A step must implement `call(context)`. That's it. No base class to inherit, no module to include. The context is an `Ask::Graph::Context` object — use method access or bracket access, whichever reads better:

```ruby
class SetValue
  def call(context)
    context.greeting = "hello"      # method setter
    context[:color] = "blue"        # bracket setter
  end
end

class ReadValue
  def call(context)
    puts context.greeting           # => "hello"
    puts context[:color]            # => "blue"
  end
end
```

## Conditional Steps

Use `if:` or `unless:` to control whether a step runs. The condition is a method name on the workflow class:

```ruby
module HandleCall
  class Workflow < Ask::Graph
    step BookAppointment,  if: :booking?
    step EmergencyAlert,   if: :emergency?
    step HandleInquiry,    unless: :known_intent?

    private

    def booking?   = context.intent == "booking"
    def emergency? = context.intent == "emergency"
    def known_intent? = %w[booking emergency inquiry].include?(context.intent)
  end
end
```

A step is skipped when its condition returns false (`if:`) or true (`unless:`). Skipped steps don't affect the context or trigger hooks. Steps after a skipped step run normally.

## Parallel Execution

Use `steps` (plural) to run multiple steps simultaneously. All steps run in parallel threads, and the workflow waits for all to finish before continuing:

```ruby
module SyncData
  class Workflow < Ask::Graph
    step FetchRecords

    # All three run in parallel
    steps CrmUpdate, CalendarSync, SendNotification

    step ConfirmResponse
  end
end
```

Parallel steps share the same context — each step reads from and writes to it concurrently. Use thread-safe operations (the context is mutex-protected). If any step fails, the entire group fails.

## Sub-Workflows

A step can delegate to another workflow. This is how you compose larger processes from smaller, reusable workflows.

```ruby
module NotifyCustomer
  class Workflow < Ask::Graph
    step SendEmail
    step LogNotification
  end
end
```

Wrap it in a PORO step that calls `Workflow.call(context)`:

```ruby
module OrderFulfillment
  class NotifyCustomer
    def call(context)
      NotifyCustomer::Workflow.call(context)
    end
  end

  class Workflow < Ask::Graph
    step ValidatePayment
    step NotifyCustomer
    step ShipOrder
  end
end
```

`NotifyCustomer::Workflow.call(context)` exports the current context, creates the sub-workflow, runs it, and merges every result back. The sub-workflow sees all the outer context's data — no special wiring required.

You can also use `context.run` for the same thing:

```ruby
class NotifyCustomer
  def call(context)
    context.run(NotifyCustomer::Workflow)
  end
end
```

Sub-workflows support nesting — a sub-workflow can call another sub-workflow. Timeouts, retries, and conditions on the outer step apply to the entire sub-workflow as a unit.

### Suggested directory layout

```
app/workflows/
  notify_customer/
    workflow.rb          # module NotifyCustomer; class Workflow < Ask::Graph
    steps/
      send_email.rb
      log_notification.rb
  order_fulfillment/
    workflow.rb          # module OrderFulfillment; class Workflow < Ask::Graph
    steps/
      validate_payment.rb
      notify_customer.rb
      ship_order.rb
```

The directory name acts as the module namespace. `workflow.rb` holds the graph class. `steps/` holds the step POROs.

## Human-in-the-Loop (Approve)

Use `approve` to pause a workflow and wait for external input. The step runs, then the workflow saves its checkpoint and raises a pause signal. Call `resume` on the same instance to continue:

```ruby
module ProcessBooking
  class Workflow < Ask::Graph
    step BookAppointment
    approve ReviewBooking, if: :expensive?
    step ConfirmBooking
  end
end
```

```ruby
graph = ProcessBooking::Workflow.new(input)
result = graph.call                  # runs, pauses after ReviewBooking

# Later, when the operator responds:
result = graph.resume(input: "approved")  # resumes, runs ConfirmBooking
```

The `approve` step's context changes are preserved in the checkpoint. When you resume, the workflow skips the approve step and continues with the remaining steps.

## Timeouts

Set a timeout on any step. If the step takes longer than the given seconds, it raises `Ask::Graph::StepFailed`.

```ruby
step FetchApi, timeout: 10, retry: 2
```

Set a default timeout for all steps in a workflow with `step_timeout`:

```ruby
module ApiWorkflow
  class Workflow < Ask::Graph
    step_timeout 30
    step FastOp           # uses 30s
    step SlowOp, timeout: 120  # overrides
  end
end
```

Set a global default for every workflow:

```ruby
Ask::Graph.default_step_timeout 30
```

Resolution order: step `timeout:` → workflow `step_timeout` → `Ask::Graph.default_step_timeout`. Set `step_timeout nil` on a child workflow to explicitly clear the parent's default.

## Workflow Timeout

A step timeout caps how long one step may run. A **workflow timeout** caps how long the entire workflow may run. If the total runtime exceeds the limit, the workflow aborts with `Ask::Graph::WorkflowTimeout` — even when no individual step exceeded its own timeout.

```ruby
module ApiWorkflow
  class Workflow < Ask::Graph
    workflow_timeout 60   # the whole workflow must finish within 60s

    step_timeout 30       # each step still capped at 30s
    step FetchData
    step ProcessData
    step StoreData
  end
end
```

Use this when a workflow has a business-level SLA — "this process must complete within a minute" — regardless of how many steps it contains or how long each one takes.

Set a global default for every workflow:

```ruby
Ask::Graph.default_workflow_timeout 60
```

Resolution order: workflow `workflow_timeout` → `Ask::Graph.default_workflow_timeout`.

## Retry

Retry a step when it fails. The step is retried up to the specified number of times with exponential backoff:

```ruby
step FlakyOp, retry: 3
```

If all retries are exhausted, `Ask::Graph::StepFailed` is raised. The `on_failure` hook fires before each retry and on the final failure.

```ruby
step FetchApi, timeout: 10, retry: 2
```

Timeouts also trigger retries. Each attempt runs within the timeout window, and a timeout counts as a failure for retry purposes.

## Lifecycle Hooks

Observe or intervene at each step boundary:

| Hook | When it fires |
|---|---|
| `before_step` | Before every step |
| `after_step` | After every successful step |
| `on_failure` | When a step fails |

```ruby
module MonitoredWorkflow
  class Workflow < Ask::Graph
    before_step :log_start
    after_step  :log_completion
    on_failure  :alert_team

    step ProcessPayment, timeout: 15, retry: 2
  end
end
```

Hooks receive `declaration:` and `context:` keyword arguments. `on_failure` also receives `error:` with the failure message:

```ruby
def log_start(declaration:, context:)
  Rails.logger.info "Starting #{declaration[:name]}"
end

def alert_team(declaration:, context:, error:)
  SlackNotifier.alert("Step failed: #{error.message}")
end
```

Hooks are inherited by subclasses and can be stacked — multiple `before_step` declarations all fire in order.

## Crash Recovery (Checkpointing)

By default, workflows use an in-memory store. If the process crashes, the workflow restarts from the beginning. Pass a storage backend to make workflows durable across restarts:

```ruby
store = Ask::State::Memory.new   # default, dies on restart
store = RedisStore.new            # survives restarts
store = PostgresStore.new         # or any backend with #set and #get

result = OrderFulfillment::Workflow.call(input, storage: store)

# If a crash occurs, resume from the last completed step:
result = OrderFulfillment::Workflow.call(input, storage: store)
```

Set a default storage for all workflows:

```ruby
Ask::Graph.storage RedisPool.new

# Every workflow uses it automatically
result = MyWorkflow.call(input)
```

Override per-graph or per-call:

```ruby
class MyWorkflow < Ask::Graph
  storage PostgresStore.new
end

MyWorkflow.call(input)                          # uses PostgresStore
MyWorkflow.call(input, storage: InMemory.new)   # overrides per-call
```

## Per-Item Iteration

When a step needs to process a list of items — sending notifications, processing records — use `context.each` inside the step. It automatically checkpoints after each item, so a crash mid-list resumes from the last completed item:

```ruby
class SendVoiceReminders
  def call(context)
    context.each(context.appointments) do |appt|
      PhoneService.call(appt.number, appt.message)
    end
  end
end

module DailyReminders
  class Workflow < Ask::Graph
    step FetchAppointments
    step SendVoiceReminders
    step MarkComplete
  end
end
```

`context.item` gives you the current item being processed, accessible anywhere inside the block.

## Error Handling

When a step fails, `Ask::Graph::StepFailed` is raised with the step name in the message:

```ruby
begin
  MyWorkflow::Workflow.call(input)
rescue Ask::Graph::StepFailed => e
  puts e.message  # => "RiskyOperation failed: connection timeout"
end
```

The `on_failure` hook fires before the exception is raised, giving you a chance to log, alert, or clean up.

## Step Metadata

Attach a human-readable description to any step:

```ruby
step ValidateOrder, description: "Verify order details with inventory system"
step ChargeCustomer, description: "Process payment via Stripe"
```

The description is available in the declaration for debugging, monitoring, and hook callbacks.

## Inheritance

Child workflow classes inherit steps and hooks from their parent. Adding new steps to the child doesn't affect the parent:

```ruby
class Parent < Ask::Graph
  step ValidateOrder
end

class Child < Parent
  step ChargeCustomer
end

Parent.declarations.size  # => 1
Child.declarations.size   # => 2
```

## Configuration Reference

| Option | Where | Purpose |
|---|---|---|
| `timeout` | step option | Max seconds per step |
| `step_timeout` | class method | Default timeout for all steps in this workflow |
| `Ask::Graph.default_step_timeout` | global | Default step timeout for every workflow |
| `workflow_timeout` | class method | Total runtime cap for the entire workflow |
| `Ask::Graph.default_workflow_timeout` | global | Default total runtime cap for every workflow |
| `retry` | step option | Number of retries on failure |
| `storage` | class method | Checkpoint backend for this workflow |
| `Ask::Graph.storage` | global | Default checkpoint backend for all workflows |
| `storage:` | `.call` param | Override storage per-call |

## Next Steps

- [Explore all core components](/ask-docs/core)
- [Build custom tools](/ask-docs/extending/custom-tools) to use inside steps
- [Set up monitoring](/ask-docs/production/monitoring) for production workflows
