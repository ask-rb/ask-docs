# frozen_string_literal: true

# Re-record a single example block live (needs a provider key in .env).
#
#   FILE=getting-started/first-agent.md PATTERN="Create a file called" ruby bin/rerun-example.rb
#   FILE=getting-started/first-agent.md PATTERN="Create a file called" REPLAY=1 ruby bin/rerun-example.rb
#
# Records only the recorded block whose code contains PATTERN, saves a fresh
# tape, and rewrites that block's `# =>` slots in the markdown. With REPLAY=1
# it replays the existing tape instead (deterministic, no key needed) — useful
# for re-applying a freshly recorded output after editing the markdown.

require_relative "../lib/docs_examples"

file = File.join(DocsExamples::ROOT, ENV.fetch("FILE"))
pattern = ENV.fetch("PATTERN")
mode = ENV["REPLAY"] ? :verify : :generate

DocsExamples.setup!
DocsExamples.install_recorder_hook!

blocks = DocsExamples.extract_blocks(file)
block = blocks.find { |b| b.recorded? && b.code_lines.join.include?(pattern) }
abort "no recorded block in #{ENV["FILE"]} contains #{pattern.inspect}" unless block

recorder = DocsExamples.recorder_for(block, mode)
DocsExamples.current_recorder = recorder
begin
  replacements = DocsExamples.run_block(block)
ensure
  DocsExamples.current_recorder = nil
end
recorder.save if mode == :generate
puts "replayed #{recorder.recording_path.delete_prefix("#{DocsExamples::ROOT}/")}" if mode == :verify

lines = File.readlines(file)
pending = replacements.map do |(from, to), replacement_lines|
  [block.fence_line + from, block.fence_line + to, replacement_lines.map { |l| "#{l}\n" }]
end
pending.sort_by { |from, _to, _| from }.reverse_each do |from, to, replacement|
  lines[from..to] = replacement
end
File.write(file, lines.join)
puts "updated #{ENV["FILE"]} (block at fence line #{block.fence_line})"
