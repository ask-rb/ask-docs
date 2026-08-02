# frozen_string_literal: true

# Executable-examples runner for ask-docs.
#
# The docs contain ruby examples whose outputs must match the real gems.
# This runner extracts the runnable ones, executes them against the ask-*
# gems, and fills in the `# =>` output slots with the actual results.
#
# Conventions:
#
# - A fenced ruby block whose first non-blank line is `require "ask..."` is
#   runnable. Everything else (Rails-app-bound snippets, fragments) is left
#   alone.
# - A line ending in `# =>` is an output slot. The generator evaluates that
#   expression after the block has run and replaces the value.
# - A bare `# =>` comment block following a code line (e.g. the multi-line
#   pretty hash examples) is also a slot: the preceding code line is the
#   expression.
# - Multi-line values are formatted with pretty_inspect and indented under
#   the `# => `.
# - A block containing a line matching `# not-verified` is skipped. Use it
#   for examples that can't run standalone (Rails-bound tools, live web
#   search) or whose output is intentionally illustrative.
# - A block containing a line matching `# recorded` makes live LLM calls and
#   is taped with ask-eval's Recorder. `rake docs:generate` (with a key)
#   records the provider interactions into examples/recordings/; `rake
#   docs:verify` replays them, so the block is verified without a key and
#   without hitting the network.
# - A block that requires a missing API key (ENV.fetch("X") with no default,
#   where X is not set) is skipped. Keys live in .env (gitignored); without
#   them the keyless examples still run and verify in CI.
#
# Usage:
#   ruby -Ilib lib/docs_examples.rb verify     # dry run, exits 1 on any diff
#   ruby -Ilib lib/docs_examples.rb generate   # rewrites the markdown files
#   FILE=core/tools.md ruby -Ilib lib/docs_examples.rb verify
#
# Gems are found as sibling repos (../ask-*) unless ASK_GEMS_ROOT is set.

require "pp"
require "stringio"

module DocsExamples
  ROOT = File.expand_path("..", __dir__)
  GEMS_ROOT = ENV.fetch("ASK_GEMS_ROOT") { File.expand_path("..", ROOT) }
  RECORDINGS_DIR = File.join(ROOT, "examples", "recordings")

  NOT_VERIFIED = /\A\s*#\s*not-verified\s*\z/
  RECORDED = /\A\s*#\s*recorded\s*\z/
  REQUIRED_KEY = /ENV\.fetch\(\s*["']([A-Z0-9_]+)["']\s*\)/
  TRAILING_SLOT = /^(.*?)\s*#\s*=>\s*(.*)$/
  BARE_SLOT = /\A\s*#\s*=>/
  COMMENT_LINE = /\A\s*#/
  RUNNABLE = /\Arequire ["']ask/

  # ------------------------------------------------------------------ setup

  def self.setup!
    Dir[File.join(GEMS_ROOT, "ask-*", "lib")].each do |path|
      $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
    end
    load_dotenv
  end

  def self.load_dotenv(path = File.join(ROOT, ".env"))
    return unless File.exist?(path)

    File.readlines(path).each do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      key, _, value = line.partition("=")
      ENV[key.strip] = value.strip unless ENV.key?(key.strip)
    end
  end

  # --------------------------------------------------- recorder integration

  class << self
    # The Recorder active for the block currently being executed, or nil.
    attr_accessor :current_recorder
  end

  # Hooks Ask::Provider#chat (the base class every provider inherits), so it
  # covers both sessions (Chat -> build_provider -> provider.chat) and direct
  # provider.chat calls. Only active while DocsExamples.current_recorder is
  # set; the runner process is the only place the hook lives.
  module ProviderRecorderHook
    def chat(*args, **kwargs, &block)
      recorder = DocsExamples.current_recorder
      return super unless recorder

      if recorder.replaying?
        recorder.replay_as_message
      else
        result = super
        recorder.record_call(args: args, kwargs: kwargs, result_data: recorder.send(:serialize, result))
        result
      end
    end
  end

  @hook_installed = false

  def self.install_recorder_hook!
    return if @hook_installed

    require "ask"              # ask-core: Ask::Provider
    require "ask-llm-providers" # registers all 33 providers
    require "ask-eval"          # Ask::Eval::Recorder
    # Prepend to the base (custom providers that don't override chat) and to
    # every registered provider class: OpenAI, Anthropic, and the compat
    # subclasses all override chat, so a base-only hook would never fire.
    Ask::Provider.prepend(ProviderRecorderHook)
    Ask::Provider.providers.values.each { |klass| klass.prepend(ProviderRecorderHook) }
    @hook_installed = true
  end

  def self.recorder_for(block, mode)
    install_recorder_hook!
    name = "#{File.basename(block.file, ".md")}-#{block.fence_line}"
    Ask::Eval::Recorder.new(
      test_name: name,
      mode: mode == :generate ? :record : :replay,
      recordings_dir: RECORDINGS_DIR
    )
  end

  # ------------------------------------------------------------- block model

  Block = Struct.new(:file, :fence_line, :code_lines) do
    # fence_line: 1-based line number of the opening ```ruby fence.
    # code_lines: the lines between the fences, chomped.

    def runnable?
      first = code_lines.find { |l| !l.strip.empty? && !l.strip.start_with?("#") }
      first&.match?(RUNNABLE) || false
    end

    def not_verified?
      code_lines.any? { |l| l.match?(NOT_VERIFIED) }
    end

    def recorded?
      code_lines.any? { |l| l.match?(RECORDED) }
    end

    def missing_key
      code_lines.each do |line|
        if (m = line.match(REQUIRED_KEY))
          return m[1] unless ENV.key?(m[1])
        end
      end
      nil
    end

    # Output slots: [replace_from, replace_to, expr] indices into code_lines.
    #
    # Pattern A: `expr # => rest` — the slot line itself is replaced.
    # Pattern B: a bare `# =>` comment block right after a code line — the
    #   code line is the expression, only the comment lines are replaced.
    def slots
      slots = []
      code_lines.each_with_index do |line, i|
        if (m = line.match(TRAILING_SLOT)) && !m[1].strip.empty?
          expr = m[1].strip
          next if expr.match?(/\A(?:puts|print|p|warn|logger)\b/)

          # A trailing slot is a single line: don't consume following comment
          # lines, which may be unrelated explanatory comments.
          slots << [i, i, expr]
        elsif line.match?(BARE_SLOT) && i > 0 && code_lines[i - 1].match?(/\A\S/) &&
              !code_lines[i - 1].match?(TRAILING_SLOT) &&
              !code_lines[i - 1].match?(/\A(?:puts|print|p|warn|logger)\b/)
          expr = code_lines[i - 1].strip
          j = i + 1
          j += 1 while j < code_lines.length && code_lines[j].match?(COMMENT_LINE)
          slots << [i, j - 1, expr]
        end
      end
      slots
    end

    def code_without_slots
      lines = code_lines.dup
      slots.each do |(from, to, _expr)|
        (from..to).each { |i| lines[i] = lines[i].sub(/\s*#\s*=>.*\z/, "") }
      end
      lines.join("\n")
    end
  end

  # --------------------------------------------------------------- scanning

  def self.markdown_files
    Dir[File.join(ROOT, "**", "*.md")].reject do |f|
      f.start_with?(File.join(ROOT, "_site"), File.join(ROOT, ".ask")) ||
        f.include?("/.git/") ||
        %w[README.md CHANGELOG.md].include?(File.basename(f))
    end
  end

  def self.extract_blocks(file)
    lines = File.readlines(file)
    blocks = []
    i = 0
    while i < lines.length
      if (m = lines[i].match(/^```(\S*)/))
        lang = m[1].delete_prefix(".").split(" ").first
        fence_idx = i
        i += 1
        code = []
        while i < lines.length && !lines[i].match?(/^```/)
          code << lines[i].chomp
          i += 1
        end
        blocks << Block.new(file, fence_idx + 1, code) if lang == "ruby"
        i += 1 # skip the closing fence
      else
        i += 1
      end
    end
    blocks
  end

  # ------------------------------------------------------------ formatting

  def self.format_value(value)
    s = value.inspect
    s = value.pretty_inspect if s.length > 100 && value.respond_to?(:pretty_inspect)
    s
  end

  def self.slot_replacement(value)
    lines = format_value(value).split("\n", -1)
    lines.pop while lines.last.to_s.empty?
    ["# => #{lines.first}"] + lines.drop(1).map { |l| "# #{l}" }
  end

  # Build the replacement lines for one slot. For a trailing slot
  # (`expr # => old`), keep the expression and replace only the comment, so
  # `tool.name # => "greeter"` stays readable. For a bare slot (comment
  # block after a code line), the expression line is untouched already.
  def self.slot_lines_for(block, from, to, value)
    orig = block.code_lines[from]
    if (m = orig.match(/\s+#\s*=>/))
      # Keep the expression and its alignment spaces; replace only the comment.
      prefix = orig[0...orig.index("#", m.begin(0))]
      lines = slot_replacement(value)
      [prefix + lines.first] + lines.drop(1).map { |l| "# #{l}" }
    else
      slot_replacement(value)
    end
  end

  # --------------------------------------------------------------- running

  def self.run_block(block)
    # Fresh binding with an Object-level cref, so eval'd `module Ask` blocks
    # reopen the real ::Ask instead of defining DocsExamples::Ask and
    # shadowing it for every later block.
    bind = TOPLEVEL_SCOPE_FACTORY.call
    code_start = block.fence_line + 1

    # Silence block stdout: examples that print are showing their output in
    # the docs as comments, not to the runner's console.
    original_stdout = $stdout
    $stdout = StringIO.new
    begin
      eval(block.code_without_slots, bind, "#{block.file}:#{code_start}", code_start)
    ensure
      $stdout = original_stdout
    end

    replacements = {}
    block.slots.each do |(from, to, expr)|
      value = eval(expr, bind, "#{block.file}:#{code_start + from}", 0)
      # A flaky upstream (rate limit, empty LLM reply) can yield "" or nil.
      # Don't clobber an existing non-empty doc value with that; warn instead.
      if (value.nil? || (value.respond_to?(:empty?) && value.empty?)) && !block.code_lines[to].match?(/=>\s*"\s*"\s*$/)
        warn "  [warn] #{relative(block.file)}:#{block.fence_line} slot #{expr.inspect} yielded empty value; keeping existing output"
        next
      end
      replacements[[from, to]] = slot_lines_for(block, from, to, value)
    end
    replacements
  end

  def self.rewrite_blocks(file, mode)
    lines = File.readlines(file)
    original = lines.join
    blocks = extract_blocks(file)
    stats = { run: 0, slots: 0, skipped_not_verified: 0, skipped_key: 0, errors: [] }

    blocks.each do |block|
      unless block.runnable?
        stats[:skipped_not_verified] += 1 if block.not_verified?
        next
      end
      if block.not_verified?
        stats[:skipped_not_verified] += 1
        next
      end
      if (key = block.missing_key)
        stats[:skipped_key] += 1
        warn "  [skip] #{relative(block.file)}:#{block.fence_line} needs #{key}"
        next
      end

      recorder = nil
      if block.recorded?
        recorder = recorder_for(block, mode)
        if mode == :verify && !File.exist?(recorder.recording_path)
          stats[:errors] << "#{relative(block.file)}:#{block.fence_line} missing recording " \
                            "(#{recorder.recording_path.delete_prefix("#{ROOT}/")}); " \
                            "run `rake docs:generate` with the key to create it"
          next
        end
      end

      begin
        DocsExamples.current_recorder = recorder
        replacements = run_block(block)
      rescue StandardError, ScriptError => e
        stats[:errors] << "#{relative(block.file)}:#{block.fence_line} #{e.class}: #{e.message.lines.first.strip}"
        next
      ensure
        DocsExamples.current_recorder = nil
      end

      recorder&.save if mode == :generate

      stats[:run] += 1
      stats[:slots] += replacements.size

      replacements.each do |(from, to), replacement_lines|
        # fence_line is 1-based; code line `from` (0-based) sits at 0-based
        # index fence_line + from in `lines`. Replacement lines must carry
        # their own "\n" because lines.join concatenates without separators.
        idx = block.fence_line + from
        lines[idx..(block.fence_line + to)] = replacement_lines.map { |l| "#{l}\n" }
      end
    end

    [original, lines.join, stats]
  end

  def self.relative(path)
    path.delete_prefix("#{ROOT}/")
  end

  # ------------------------------------------------------------------- CLI

  def self.run(mode)
    setup!
    filter = ENV["FILE"]
    files = filter ? [File.join(ROOT, filter)] : markdown_files
    failures = []
    changed = []

    files.each do |file|
      next unless File.exist?(file)

      original, rewritten, stats = rewrite_blocks(file, mode)
      if original != rewritten
        if mode == :generate
          File.write(file, rewritten)
          changed << relative(file)
        else
          failures << relative(file)
        end
      end
      print_stats(relative(file), stats)
      stats[:errors].each { |e| warn "  [error] #{e}" }
    end

    puts "#{changed.size} file(s) updated" if mode == :generate && changed.any?
    if mode == :verify
      if failures.any?
        warn "verify failed: #{failures.size} file(s) have stale example outputs:"
        failures.each { |f| warn "  - #{f} (run `rake docs:generate#{filter ? " FILE=#{filter}" : ""}` to update)" }
        exit 1
      else
        puts "verify: all example outputs are up to date"
      end
    end
  end

  def self.print_stats(file, stats)
    puts "[#{file}] ran=#{stats[:run]} slots=#{stats[:slots]} " \
         "skipped(not-verified)=#{stats[:skipped_not_verified]} " \
         "skipped(key)=#{stats[:skipped_key]} errors=#{stats[:errors].size}"
  end
end

# Binding factory defined at the file's top level so eval'd code gets an
# Object cref: `module Ask` reopens the real ::Ask instead of defining a
# DocsExamples::Ask that shadows it for later blocks.
TOPLEVEL_SCOPE_FACTORY = proc do
  Object.new.instance_eval { binding }
end

if $PROGRAM_NAME == __FILE__
  mode = ARGV[0]
  abort "usage: #{$PROGRAM_NAME} verify|generate" unless %w[verify generate].include?(mode)

  DocsExamples.run(mode.to_sym)
end
