require "test_helper"
require "tmpdir"

class Classy::YamlPerformanceTest < ActiveSupport::TestCase
  setup do
    @original_cache_classes = Rails.application.config.cache_classes
    @original_cache_size = Classy::Yaml.cache_size
    @directory = Dir.mktmpdir("classy-performance")
    @path = File.join(@directory, "classes.yml")
    @component_path = File.join(@directory, "component.yml")
    File.write(@path, "single: px-2\nconflict: p-2\nother: p-4\nleft:\n  pad: p-2\nright:\n  pad: p-4\nnested:\n  base: rounded\n  item: m-2\n")
    File.write(@component_path, "single: px-6\n")
    Classy::Yaml.setup do |config|
      config.default_file = @path
      config.engine_files = []
      config.extra_files = [ @component_path ]
    end
    @helper = Object.new.extend(Classy::Yaml::Helpers)
  end

  teardown do
    Rails.application.config.cache_classes = @original_cache_classes
    Classy::Yaml.cache_size = @original_cache_size
    Classy::Yaml.setup do |config|
      config.default_file = "config/utility_classes.yml"
      config.engine_files = []
      config.extra_files = []
    end
    FileUtils.remove_entry(@directory)
  end

  test "repeated calls reuse the result without file, lookup or merge work" do
    args = [ { nested: :item, add: "px-9" }, :single, { classy_files: [ @component_path ] } ]
    expected = @helper.yass(*args)

    counts = count_calls do
      3.times { assert_equal expected, @helper.yass(*args) }
    end

    assert_equal 0, counts[:merges], "tailwind_merge ran again"
    assert_equal 0, counts[:file_lookups], "YAML files were looked up again"
    assert_equal 0, counts[:splits], "YAML strings were split again"
  end

  test "without the result cache a lookup splits no YAML strings" do
    Classy::Yaml.cache_size = 0
    assert_equal "px-6 rounded m-2", @helper.yass(:single, nested: :item, classy_files: [ @component_path ])

    counts = count_calls do
      3.times { assert_equal "px-6 rounded m-2", @helper.yass(:single, nested: :item, classy_files: [ @component_path ]) }
    end

    assert_equal 0, counts[:splits]
    assert_equal 0, Classy::Yaml.instance_variable_get(:@results).size
  end

  test "argument and hash order are part of the cached arguments" do
    assert_equal "p-4", @helper.yass(:conflict, :other)
    assert_equal "p-2", @helper.yass(:other, :conflict)

    # These hashes are eql? but list their keys in a different order.
    assert_equal "p-4", @helper.yass(left: :pad, right: :pad)
    assert_equal "p-2", @helper.yass(right: :pad, left: :pad)
  end

  test "setup and every file setter start a new generation" do
    generations = [ Classy::Yaml.generation ]
    Classy::Yaml.setup { |_| }
    generations << Classy::Yaml.generation
    Classy::Yaml.default_file = @path
    generations << Classy::Yaml.generation
    Classy::Yaml.engine_files = []
    generations << Classy::Yaml.generation
    Classy::Yaml.extra_files = []
    generations << Classy::Yaml.generation

    assert_equal generations.sort.uniq, generations
  end

  test "a setter between calls changes the next result" do
    assert_equal "px-6", @helper.yass(:single)
    Classy::Yaml.extra_files = []
    assert_equal "px-2", @helper.yass(:single)
  end

  test "a result computed before a new generation is not stored" do
    cache = Classy::Yaml::ResultCache.new(10)
    generation = cache.generation
    cache.invalidate
    cache.store([ :key ], "stale", generation)
    assert_nil cache.get([ :key ])

    cache.store([ :key ], "fresh", cache.generation)
    assert_equal "fresh", cache.get([ :key ])
  end

  test "the result cache keeps the most recently used entries within its size" do
    cache = Classy::Yaml::ResultCache.new(2)
    cache.store(:a, "a", 0)
    cache.store(:b, "b", 0)
    cache.get(:a)
    cache.store(:c, "c", 0)

    assert_equal 2, cache.size
    assert_equal "a", cache.get(:a)
    assert_nil cache.get(:b)
    assert_equal "c", cache.get(:c)

    cache.max_size = 1
    assert_equal 1, cache.size
  end

  test "yass keeps at most cache_size results" do
    Classy::Yaml.cache_size = 3
    10.times { |index| @helper.yass(:single, add: "px-#{index}") }
    assert_equal 3, Classy::Yaml.instance_variable_get(:@results).size
  end

  test "calls that log an invalid key warning log it every time" do
    log = StringIO.new
    original_logger = Rails.logger
    Rails.logger = Logger.new(log)
    3.times { assert_equal "px-6", @helper.yass(single: :child) }
    # Two files define single as a string: one warning for each, on every call.
    assert_equal 6, log.string.scan("yass called with invalid keys").size
  ensure
    Rails.logger = original_logger
  end

  test "callers cannot change a cached result or its arguments" do
    @helper.instance_variable_set(:@tailwind_merge_available, false)
    first = @helper.yass(:single, add: "extra")
    first << " mutated"
    assert_equal "px-6 extra", @helper.yass(:single, add: "extra")
    assert_not @helper.yass(:single, add: "extra").frozen?

    key = +"single"
    assert_equal "px-6", @helper.yass(key)
    key.replace("conflict")
    assert_equal "px-6", @helper.yass("single")
    assert_equal "p-2", @helper.yass("conflict")
  end

  test "arguments that are not plain values bypass the cache" do
    token = Struct.new(:name) do
      def to_s
        name
      end
    end.new("single")
    assert_equal "px-6", @helper.yass(token)
    token.name = "conflict"
    assert_equal "p-2", @helper.yass(token)
  end

  test "while reloading each request checks each YAML file once" do
    Rails.application.config.cache_classes = false
    lookup = -> { @helper.yass(:single, nested: :item, classy_files: [ @component_path ]) }
    assert_equal "px-6 rounded m-2", request(&lookup)

    stats = count_stats do
      assert_equal [ "px-6 rounded m-2" ] * 10, request { Array.new(10) { lookup.call } }
    end
    assert_equal 2, stats, "one File.stat per known YAML file per request"

    File.write(@component_path, "single: px-12\n")
    assert_equal "px-12 rounded m-2", request(&lookup)
    stats = count_stats { 10.times { lookup.call } }
    assert_equal 0, stats, "no File.stat between requests"
  end

  test "with classes cached a request checks no files" do
    assert_equal "px-6", @helper.yass(:single)
    File.write(@component_path, "single: px-12\n")
    stats = count_stats { assert_equal "px-6", request { @helper.yass(:single) } }
    assert_equal 0, stats
  end

  test "a broken YAML file is read once while classes are cached" do
    File.write(@component_path, "single: [\n")
    Classy::Yaml.setup { |_| }
    log = StringIO.new
    original_logger = Rails.logger
    Rails.logger = Logger.new(log)
    stats = count_stats { 3.times { |index| assert_equal "px-2 m-#{index}", @helper.yass(:single, add: "m-#{index}") } }
    assert_equal 2, stats, "one File.stat for each of the two files"
    assert_equal 1, log.string.scan("Failed to parse").size
  ensure
    Rails.logger = original_logger
  end

  test "component YAML candidates are computed once per component class" do
    component = Class.new
    component.define_singleton_method(:name) { "Classy::YamlPerformanceTest" }
    first = Classy::Yaml.component_classy_files(component)
    lookups = 0
    trace = TracePoint.new(:c_call) { |event| lookups += 1 if event.method_id == :const_source_location }
    trace.enable { 3.times { assert_same first, Classy::Yaml.component_classy_files(component) } }
    assert_equal 0, lookups
    assert_equal File.join(__dir__, "yaml_performance_test.yml"), first.first
  end

  test "warm parses the YAML and builds the merger before the first call" do
    Classy::Yaml.setup { |_| }
    Classy::Yaml.warm
    counts = count_calls { assert_equal "px-6", @helper.yass(:single) }
    assert_equal 0, counts[:parses]
    assert_equal 0, counts[:merger_builds]
  end

  test "booting with classes cached warms Classy" do
    script = <<~RUBY
      require "#{File.expand_path("../dummy/config/environment", __dir__)}"
      layers = Classy::Yaml.instance_variable_get(:@static_layers)
      merger = Classy::Yaml.instance_variable_get(:@merger)
      print [ layers&.size, merger.class.name ].inspect
    RUBY
    output = IO.popen({ "RAILS_ENV" => "test" }, [ RbConfig.ruby, "-e", script ], err: File::NULL, &:read)
    assert_equal [ 1, "TailwindMerge::Merger" ].inspect, output
  end

  private

  def request(&block)
    Thread.new { Rails.application.executor.wrap(&block) }.value
  end

  def count_stats(&block)
    stats = 0
    trace = TracePoint.new(:c_call) do |event|
      stats += 1 if event.method_id == :stat && event.defined_class == File.singleton_class
    end
    trace_all_threads(trace, &block)
    stats
  end

  def count_calls(&block)
    counts = Hash.new(0)
    names = {
      [ TailwindMerge::Merger, :merge ] => :merges,
      [ TailwindMerge::Merger, :initialize ] => :merger_builds,
      [ Classy::Yaml.singleton_class, :cached_yaml_file ] => :file_lookups,
      [ Psych.singleton_class, :safe_load ] => :parses,
      [ String, :split ] => :splits
    }
    trace = TracePoint.new(:call, :c_call) do |event|
      name = names[[ event.defined_class, event.method_id ]]
      counts[name] += 1 if name
    end
    trace_all_threads(trace, &block)
    counts
  end

  # TracePoint#enable with a block traces only the current thread, and a request runs on its own.
  def trace_all_threads(trace)
    trace.enable
    yield
  ensure
    trace.disable
  end
end
