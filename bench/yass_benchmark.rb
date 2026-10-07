# Measures yass time and allocations per call for request-shaped workloads.
#
#   BUNDLE_GEMFILE=gemfiles/rails8_propshaft.gemfile bundle exec ruby --yjit --yjit-stats=quiet bench/yass_benchmark.rb
#
# A "request" is 800 yass calls drawn from 200 distinct argument shapes of the
# test corpus, close to the yass calls of one large page in a real app.
# Scenarios: warning-free shapes (the common page), the same with the result
# cache off (the uncached lookup path), a new add: value on every call (every
# call misses), shapes that log invalid key warnings, and Rails reloading code.
ENV["RAILS_ENV"] = "test"
require_relative "../test/dummy/config/environment"
require_relative "../test/support/yass_corpus"
require "json"

REQUESTS = Integer(ENV.fetch("REQUESTS", 40))

# Counts File.stat calls. A TracePoint would do it too, but enabling one makes
# YJIT drop to the interpreter for the rest of the process.
module FileStatCounter
  class << self
    attr_accessor :count
  end
  self.count = 0

  def stat(...)
    FileStatCounter.count += 1
    super
  end
end
File.singleton_class.prepend(FileStatCounter)
CALLS_PER_REQUEST = 800

config = YassCorpus::CONFIGS.fetch("all_layers")
Classy::Yaml.setup do |classy|
  config.each { |key, value| classy.public_send("#{key}=", value) }
  classy.override_tag_helpers = false
end
Rails.logger = Logger.new(IO::NULL)

helper = Object.new.extend(Classy::Yaml::Helpers)

# Split the corpus shapes by whether they log an invalid key warning: a real
# page rarely has one, and a call that warns is recomputed on every call.
warning_log = StringIO.new
Rails.logger = Logger.new(warning_log)
valid_shapes, invalid_shapes = YassCorpus.calls.partition do |args|
  warning_log.truncate(0)
  warning_log.rewind
  helper.yass(*args)
  warning_log.string.empty?
end
Rails.logger = Logger.new(IO::NULL)

request_for = lambda do |shapes|
  random = Random.new(42)
  pool = shapes.first(200)
  Array.new(CALLS_PER_REQUEST) { pool[random.rand(pool.size)] }
end
request_calls = request_for.call(valid_shapes)
invalid_calls = request_for.call(invalid_shapes)
# Worst case for a result cache: every call ever made carries a new add: value.
unique_add = 0
unique_add_calls = Array.new(CALLS_PER_REQUEST) { |index| [ valid_shapes[index % 200], { add: -> { "px-#{unique_add += 1}" } } ] }

run_request = lambda do |calls, reloading|
  work = lambda do
    calls.each do |args|
      last = args.last
      args = [ args.first, { add: last[:add].call } ] if last.is_a?(Hash) && last[:add].is_a?(Proc)
      helper.yass(*args)
    end
  end
  reloading ? Rails.application.reloader.wrap(&work) : work.call
end

yjit_insns = lambda do
  stats = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? && RubyVM::YJIT.runtime_stats
  [ stats[:yjit_insns_count], stats[:vm_insns_count] ] if stats && stats[:yjit_insns_count]
end

measure = lambda do |name, calls, reloading, cache: true|
  Rails.application.config.cache_classes = !reloading
  Classy::Yaml.setup { |_| }
  if Classy::Yaml.respond_to?(:cache_size=)
    Classy::Yaml.cache_size = cache ? Classy::Yaml::DEFAULT_CACHE_SIZE : 0
  elsif !cache
    next nil # 1.7.2 has no result cache to turn off
  end
  5.times { run_request.call(calls, reloading) }
  GC.start
  insns_before = yjit_insns.call
  allocated = GC.stat(:total_allocated_objects)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  REQUESTS.times { run_request.call(calls, reloading) }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  allocations = GC.stat(:total_allocated_objects) - allocated
  insns_after = yjit_insns.call

  FileStatCounter.count = 0
  run_request.call(calls, reloading)
  stats = FileStatCounter.count

  {
    scenario: name,
    ms_per_request: (elapsed * 1000 / REQUESTS).round(3),
    us_per_call: (elapsed * 1_000_000 / (REQUESTS * calls.size)).round(3),
    allocations_per_call: (allocations.to_f / (REQUESTS * calls.size)).round(2),
    file_stats_per_request: stats,
    # Share of the timed yass instructions that YJIT ran (needs --yjit-stats).
    ratio_in_yjit: insns_after && begin
      yjit = insns_after[0] - insns_before[0]
      vm = insns_after[1] - insns_before[1]
      (100.0 * yjit / (yjit + vm)).round(2)
    end
  }
end

results = [
  measure.call("classes cached", request_calls, false),
  measure.call("classes cached, result cache off", request_calls, false, cache: false),
  measure.call("classes cached, every add: new", unique_add_calls, false),
  measure.call("classes cached, invalid keys (warn)", invalid_calls, false),
  measure.call("reloading (development)", request_calls, true)
].compact

yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
summary = {
  version: Classy::Yaml::VERSION,
  ruby: RUBY_DESCRIPTION,
  rails: Rails.version,
  yjit: yjit,
  # Whole process, including Rails boot; each result has the ratio of its timed loop.
  process_ratio_in_yjit: (yjit && RubyVM::YJIT.runtime_stats[:ratio_in_yjit])&.round(4),
  results: results
}
puts JSON.pretty_generate(summary)
