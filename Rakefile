# frozen_string_literal: true

require_relative "lib/docs_examples"

desc "Regenerate example outputs in the docs (fill # => slots)"
task "docs:generate" do
  DocsExamples.run(:generate)
end

desc "Verify example outputs are current (dry run, exits 1 on any diff)"
task "docs:verify" do
  DocsExamples.run(:verify)
end
