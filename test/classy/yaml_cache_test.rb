require "test_helper"
require "tmpdir"

class Classy::YamlCacheTest < ActiveSupport::TestCase
  setup do
    @original_env = Rails.env
    @original_default = Classy::Yaml.default_file
    @original_engines = Classy::Yaml.engine_files
    @original_extras = Classy::Yaml.extra_files
    @original_cache_classes = Rails.application.config.cache_classes
    Rails.application.config.cache_classes = false
    @directory = Dir.mktmpdir("classy-cache")
    @path = File.join(@directory, "classes.yml")
    Rails.env = "development"
    Classy::Yaml.setup do |config|
      config.default_file = @path
      config.engine_files = []
      config.extra_files = []
    end
    @helper = Object.new.extend(Classy::Yaml::Helpers)
  end

  teardown do
    Rails.application.config.cache_classes = @original_cache_classes
    Rails.env = @original_env
    Classy::Yaml.setup do |config|
      config.default_file = @original_default
      config.engine_files = @original_engines
      config.extra_files = @original_extras
    end
    FileUtils.remove_entry(@directory)
  end

  test "unchanged YAML is parsed once across helpers and file sources" do
    File.write(@path, "single: px-2\n")
    Classy::Yaml.engine_files = [ @path ]
    Classy::Yaml.extra_files = [ @path ]
    [ "development", "test" ].each do |environment|
      Rails.env = environment
      Classy::Yaml.setup { |_| }
      parses = 0
      trace = TracePoint.new(:call) do |event|
        parses += 1 if event.defined_class == Psych.singleton_class && event.method_id == :safe_load
      end
      trace.enable do
        3.times do
          helper = Object.new.extend(Classy::Yaml::Helpers)
          assert_equal "px-2", helper.yass(:single, classy_files: [ @path ])
        end
      end
      assert_equal 1, parses
    end
  end

  test "all YAML sources reload after edits creation deletion and replacement" do
    [ "development", "test", "production" ].product([ :default, :engine, :extra, :component ]).each do |environment, source|
      Rails.env = environment
      Classy::Yaml.setup do |config|
        config.default_file = source == :default ? @path : File.join(@directory, "missing.yml")
        config.engine_files = source == :engine ? [ @path ] : []
        config.extra_files = source == :extra ? [ @path ] : []
      end
      # While Rails reloads code, edits are picked up at the next request.
      lookup = -> { request { @helper.yass(:single, classy_files: source == :component ? [ @path ] : []) } }
      assert_equal "", lookup.call
      File.write(@path, "single: px-2\n")
      assert_equal "px-2", lookup.call
      old_mtime = File.mtime(@path)
      File.write(@path, "single: px-12\n")
      File.utime(old_mtime, old_mtime, @path)
      assert_equal "px-12", lookup.call
      replacement = File.join(@directory, "replacement.yml")
      File.write(replacement, "single: px-8\n")
      File.rename(replacement, @path)
      assert_equal "px-8", lookup.call
      File.delete(@path)
      assert_equal "", lookup.call
      File.write(@path, "single: px-6\n")
      assert_equal "px-6", lookup.call
      File.delete(@path)
    end
  end

  test "with classes cached a parsed file is never stat'ed again in any environment" do
    Rails.application.config.cache_classes = true
    File.write(@path, "single: px-2\n")
    Classy::Yaml.engine_files = [ @path ]
    Classy::Yaml.extra_files = [ @path ]
    [ "development", "test", "production" ].each do |environment|
      Rails.env = environment
      Classy::Yaml.setup { |_| }
      assert_equal "px-2", @helper.yass(:single, classy_files: [ @path ])
      stats = 0
      trace = TracePoint.new(:c_call) do |event|
        stats += 1 if event.defined_class == File.singleton_class && event.method_id == :stat
      end
      trace.enable do
        3.times { assert_equal "px-2", @helper.yass(:single, classy_files: [ @path ]) }
      end
      assert_equal 0, stats, "#{environment}: File.stat called with classes cached"
    end
  end

  test "with classes cached edits wait for a restart and a missing file is checked once" do
    Rails.application.config.cache_classes = true
    missing = File.join(@directory, "component.yml")
    File.write(@path, "single: px-2\n")
    Classy::Yaml.setup { |_| }
    assert_equal "px-2", @helper.yass(:single)
    File.write(@path, "single: px-12\n")
    assert_equal "px-2", @helper.yass(:single)

    stats = 0
    trace = TracePoint.new(:c_call) do |event|
      stats += 1 if event.defined_class == File.singleton_class && event.method_id == :stat
    end
    trace.enable { 3.times { assert_equal "px-2", @helper.yass(:single, classy_files: [ missing ]) } }
    assert_equal 1, stats

    Classy::Yaml.setup { |_| }
    assert_equal "px-12", @helper.yass(:single)
  end

  test "a file in place of a component directory is treated as missing" do
    File.write(@path, "single: px-2\n")
    original_logger = Rails.logger
    log_output = StringIO.new
    Rails.logger = Logger.new(log_output)

    2.times do
      assert_nil Classy::Yaml.cached_yaml_file(File.join(@path, "component.yml"), "classy")
    end
    assert_empty log_output.string
  ensure
    Rails.logger = original_logger
  end

  test "invalid YAML does not retain old classes and can be repaired" do
    File.write(@path, "single: px-2\n")
    assert_equal "px-2", request { @helper.yass(:single) }
    File.write(@path, "single: [\n")
    assert_equal "", request { @helper.yass(:single) }
    File.write(@path, "single: px-4\n")
    assert_equal "px-4", request { @helper.yass(:single) }
  end

  test "helpers reuse the merger cache across concurrent calls" do
    File.write(@path, "single: px-2\n")
    assert_equal "px-4", @helper.yass(:single, add: "px-4")
    constructions = 0
    trace = TracePoint.new(:call) do |event|
      constructions += 1 if event.defined_class == TailwindMerge::Merger && event.method_id == :initialize
    end
    results = trace.enable do
      Array.new(4) do
        Thread.new do
          helper = Object.new.extend(Classy::Yaml::Helpers)
          Array.new(10) { helper.yass(:single, add: "px-4") }
        end
      end.flat_map(&:value)
    end
    assert_equal [ "px-4" ] * 40, results
    assert_equal 0, constructions
  end

  private

  # Runs the block as a request does: inside a fresh Rails executor on its own thread.
  def request(&block)
    Thread.new { Rails.application.executor.wrap(&block) }.value
  end
end
