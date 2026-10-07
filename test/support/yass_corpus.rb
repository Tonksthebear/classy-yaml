# A deterministic corpus of yass calls. The golden file records the 1.7.2
# output for every call so later versions can prove byte-identical results.
#
# Regenerate the golden file only from a version whose output is the reference:
#   RAILS_ENV=test ruby test/support/generate_yass_golden.rb
module YassCorpus
  SEED = 1_7_2
  SIZE = 800
  GOLDEN_PATH = File.expand_path("yass_golden.json", __dir__)

  COMPONENT = "app/components/test_component/test_component.yml"
  NESTED_COMPONENT = "app/components/test_component/nested_component.yml"
  CORPUS = "config/corpus_classes.yml"
  MISSING = "app/components/test_component/missing.yml"
  BROKEN = "config/broken_classes.yml"

  CONFIGS = {
    "default_only" => { default_file: "config/utility_classes.yml", engine_files: [], extra_files: [] },
    "all_layers" => {
      default_file: "config/utility_classes.yml",
      engine_files: [ "config/engine_utility_classes.yml" ],
      extra_files: [ "config/extra_utility_classes.yml", CORPUS ]
    },
    "other_default" => {
      default_file: "config/non_default_classes.yml",
      engine_files: [ "config/engine_utility_classes.yml" ],
      extra_files: [ CORPUS ]
    }
  }.freeze

  ATOMS = [
    :single, :array, :array_override, :overrideable, :new_single, :extra_single,
    :engine_no_override, :engine_default_override, :engine_extra_override,
    :integer_leaf, :boolean_leaf, :empty_leaf, :blank_leaf, :nil_leaf, :symbol_leaf,
    :array_nested, :hash_in_array, :tw, :tw_override, :inherited, :nested,
    :missing, "single", "tw", "1", 1, "true", true, nil, :nested_base, :base_array, :conflict
  ].freeze

  PARENTS = [
    :nested_base, :nested_no_base, :base_array, :base_hash, :conflict, :anchors, :alias_use,
    :overrideable_nested, :overrideable_base_nested, :overrideable_no_base_nested,
    :single, :integer_leaf, :empty_leaf, :missing, "nested_base", :array
  ].freeze

  CHILDREN = [
    :nested, :nested2, :base, :deep, :small, :large, :item, :empty, :inner, :extra,
    :missing, "nested", "small", nil, 0
  ].freeze

  ADDS = [ "px-1", "p-2 px-9", [ "m-2", "p-3" ], [ "bg-blue-500", [ "px-3" ] ], "", nil, "single-class" ].freeze

  CLASSY_FILES = [
    [], [ COMPONENT ], [ COMPONENT, NESTED_COMPONENT ], [ NESTED_COMPONENT, COMPONENT ],
    [ MISSING, COMPONENT ], [ CORPUS ], [ COMPONENT, CORPUS ], [ BROKEN, COMPONENT ]
  ].freeze

  SKIP_BASE = [ true, false, nil, "yes" ].freeze

  module_function

  def calls
    random = Random.new(SEED)
    Array.new(SIZE) { call(random) }
  end

  def call(random)
    args = Array.new(random.rand(1..3)) { part(random) }
    options = {}
    options[:skip_base] = pick(random, SKIP_BASE) if random.rand < 0.2
    options[:classy_files] = pick(random, CLASSY_FILES) if random.rand < 0.35
    options[:add] = pick(random, ADDS) if random.rand < 0.3
    unless options.empty?
      case random.rand(4)
      when 0 then args << options
      when 1 then args.unshift(options)
      when 2
        # Options mixed into an existing lookup hash (or a new one).
        target = args.find { |arg| arg.is_a?(Hash) }
        target ? target.merge!(options) : args << options
      else
        # Options split across two hashes; the first hash with a key wins.
        args << options << options.transform_values { |value| value == true ? false : value }
      end
    end
    args
  end

  def part(random)
    case random.rand(10)
    when 0, 1, 2 then pick(random, ATOMS)
    when 3, 4 then { pick(random, PARENTS) => pick(random, CHILDREN) }
    when 5 then { pick(random, PARENTS) => [ pick(random, CHILDREN), pick(random, CHILDREN) ] }
    when 6 then { pick(random, PARENTS) => pick(random, CHILDREN), pick(random, PARENTS) => pick(random, CHILDREN) }
    when 7 then { base_array: { deep: [ :leaf, { deeper: pick(random, [ :bottom, :missing ]) } ] } }
    when 8 then [ pick(random, ATOMS), { pick(random, PARENTS) => pick(random, CHILDREN), add: pick(random, ADDS) } ]
    else { conflict: [ :small, :large ], add: pick(random, ADDS), tw: { add: "nested-add" } }
    end
  end

  # Hash#inspect changed in Ruby 3.4, so the golden file uses its own stable form.
  def describe(value)
    case value
    when Hash then "{#{value.map { |key, child| "#{describe(key)}=>#{describe(child)}" }.join(", ")}}"
    when Array then "[#{value.map { |child| describe(child) }.join(", ")}]"
    else value.inspect
    end
  end

  def pick(random, list)
    list[random.rand(list.size)]
  end

  # Runs every call against every configuration, with and without tailwind_merge.
  # Each call runs twice so a cached second answer is checked too.
  # Returns { "args" => [...], "results" => { "config/tailwind" => [[output, frozen, warnings], ...] } }.
  def record
    original_logger = Rails.logger
    log = StringIO.new
    Rails.logger = Logger.new(log)
    corpus = calls
    results = {}
    CONFIGS.each do |name, config|
      Classy::Yaml.setup do |classy|
        config.each { |key, value| classy.public_send("#{key}=", value) }
      end
      [ true, false ].each do |tailwind|
        helper = Object.new.extend(Classy::Yaml::Helpers)
        helper.instance_variable_set(:@tailwind_merge_available, tailwind)
        results["#{name}/#{tailwind}"] = corpus.map do |args|
          runs = Array.new(2) do
            log.truncate(0)
            log.rewind
            output = helper.yass(*args)
            [ output, output.frozen?, log.string.scan("yass called with invalid keys").size ]
          end
          runs.uniq.size == 1 ? runs.first : runs
        end
      end
    end
    { "args" => corpus.map { |args| describe(args) }, "results" => results }
  ensure
    Rails.logger = original_logger
  end
end
