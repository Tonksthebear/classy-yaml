# Measures yass time and allocations per call for request-shaped workloads.
#
#   BUNDLE_GEMFILE=gemfiles/rails8_propshaft.gemfile bundle exec ruby --yjit --yjit-stats=quiet bench/yass_benchmark.rb
#
# A "request" is 800 yass calls drawn from 200 distinct argument shapes of the
# test corpus, close to the 791 calls of a HyperFlex Reports preview request.
ENV["RAILS_ENV"] = "test"
require_relative "../test/dummy/config/environment"
require_relative "../test/support/yass_corpus"
require "json"

REQUESTS = Integer(ENV.fetch("REQUESTS", 40))
CALLS_PER_REQUEST = 800

config = YassCorpus::CONFIGS.fetch("all_layers")
Classy::Yaml.setup do |classy|
  config.each { |key, value| classy.public_send("#{key}=", value) }
  classy.override_tag_helpers = false
end
Rails.logger = Logger.new(IO::NULL)

shapes = YassCorpus.calls.first(200)
random = Random.new(42)
request_calls = Array.new(CALLS_PER_REQUEST) { shapes[random.rand(shapes.size)] }
# Worst case for a result cache: every call carries a different add: value.
unique_add_calls = Array.new(CALLS_PER_REQUEST) { |index| [ shapes[index % shapes.size], { add: "px-#{index}" } ] }

helper = Object.new.extend(Classy::Yaml::Helpers)

run_request = lambda do |calls, reloading|
  work = -> { calls.each { |args| helper.yass(*args) } }
  reloading ? Rails.application.reloader.wrap(&work) : work.call
end

measure = lambda do |name, calls, reloading|
  Rails.application.config.cache_classes = !reloading
  Classy::Yaml.setup { |_| }
  5.times { run_request.call(calls, reloading) }
  GC.start
  allocated = GC.stat(:total_allocated_objects)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  REQUESTS.times { run_request.call(calls, reloading) }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  allocations = GC.stat(:total_allocated_objects) - allocated

  stats = 0
  trace = TracePoint.new(:c_call) { |event| stats += 1 if event.method_id == :stat && event.defined_class == File.singleton_class }
  trace.enable { run_request.call(calls, reloading) }

  {
    scenario: name,
    ms_per_request: (elapsed * 1000 / REQUESTS).round(3),
    us_per_call: (elapsed * 1_000_000 / (REQUESTS * calls.size)).round(3),
    allocations_per_call: (allocations.to_f / (REQUESTS * calls.size)).round(2),
    file_stats_per_request: stats
  }
end

results = [
  measure.call("classes cached", request_calls, false),
  measure.call("classes cached, unique add:", unique_add_calls, false),
  measure.call("reloading (development)", request_calls, true)
]

yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
summary = {
  version: Classy::Yaml::VERSION,
  ruby: RUBY_DESCRIPTION,
  rails: Rails.version,
  yjit: yjit,
  ratio_in_yjit: (yjit && RubyVM::YJIT.runtime_stats[:ratio_in_yjit])&.round(4),
  results: results
}
puts JSON.pretty_generate(summary)
