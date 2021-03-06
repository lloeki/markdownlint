require_relative 'setup_tests'
require 'open3'
require 'set'

class TestCli < Minitest::Test
  def run_cli(args, stdin = "", mdlrc="default_mdlrc")
    mdl_script = File.expand_path("../../bin/mdl", __FILE__)
    # Load the mdlrc file from the text/fixtures/ directory
    mdlrc = File.expand_path("../fixtures/#{mdlrc}", __FILE__)
    result = {}
    result[:stdout], result[:stderr], result[:status] = \
      Open3.capture3(*(%W{bundle exec #{mdl_script} -c #{mdlrc}} + args.split),
                    :stdin_data => stdin)
    result[:status] = result[:status].exitstatus
    result
  end

  def assert_rules_enabled(result, rules, only_these_rules=false)
    # Asserts that the given rules are enabled given the output of mdl -l
    # If only_these_rules is set, then it asserts that the given rules and no
    # others are enabled.
    lines = result[:stdout].split("\n")
    assert_equal("Enabled rules:", lines.first)
    lines.shift
    rules = rules.to_set
    enabled_rules = lines.map{ |l| l.split(" ").first }.to_set
    if only_these_rules
      assert_equal(rules, enabled_rules)
    else
      assert_equal(Set.new, rules - enabled_rules)
    end
  end

  def assert_rules_disabled(result, rules)
    # Asserts that the given rules are _not_ enabled given the output of mdl -l
    lines = result[:stdout].split("\n")
    assert_equal("Enabled rules:", lines.first)
    lines.shift
    rules = rules.to_set
    enabled_rules = lines.map{ |l| l.split(" ").first }.to_set
    assert_equal(Set.new, rules & enabled_rules)
  end

  def test_help_text
    result = run_cli("--help")
    assert_match(/Usage: \S+ \[options\]/, result[:stdout])
    assert_equal(0, result[:status])
  end

  def test_default_ruleset_loading
    result = run_cli("-l")
    assert_rules_enabled(result, ["MD001"])
  end

  def test_skipping_default_ruleset_loading
    result = run_cli("-ld")
    assert_rules_enabled(result, [], true)
  end

  def test_custom_ruleset_loading
    my_ruleset = File.expand_path("../fixtures/my_ruleset.rb", __FILE__)
    result = run_cli("-ldu #{my_ruleset}")
    assert_equal(0, result[:status])
    assert_rules_enabled(result, ["MY001"], true)
    assert_equal("", result[:stderr])
  end

  def test_custom_ruleset_processing_success
    my_ruleset = File.expand_path("../fixtures/my_ruleset.rb", __FILE__)
    result = run_cli("-du #{my_ruleset}", "Hello World")
    assert_equal("", result[:stdout])
    assert_equal("", result[:stderr])
    assert_equal(0, result[:status])
  end

  def test_custom_ruleset_processing_failure
    my_ruleset = File.expand_path("../fixtures/my_ruleset.rb", __FILE__)
    result = run_cli("-du #{my_ruleset}", "Goodbye world")
    assert_equal(1, result[:status])
    assert_match(/^\(stdin\):1: MY001/, result[:stdout])
    assert_equal("", result[:stderr])
  end

  def test_custom_ruleset_loading_with_default
    my_ruleset = File.expand_path("../fixtures/my_ruleset.rb", __FILE__)
    result = run_cli("-lu #{my_ruleset}")
    assert_equal(0, result[:status])
    assert_rules_enabled(result, ["MD001", "MY001"])
    assert_equal("", result[:stderr])
  end

  def test_rule_inclusion_cli
    result = run_cli("-r MD001 -l")
    assert_equal(0, result[:status])
    assert_rules_enabled(result, ["MD001"], true)
    assert_equal("", result[:stderr])
  end

  def test_rule_exclusion_cli
    result = run_cli("-r ~MD001 -l")
    assert_rules_disabled(result, ["MD001"])
    assert_equal(0, result[:status])
    assert_equal("", result[:stderr])
  end

  def test_rule_inclusion_with_exclusion_cli
    result = run_cli("-r ~MD001,MD039 -l")
    assert_equal(0, result[:status])
    assert_rules_enabled(result, ["MD039"], true)
    assert_equal("", result[:stderr])
  end

  def test_tag_inclusion_cli
    result = run_cli("-t headers -l")
    assert_equal(0, result[:status])
    assert_equal("", result[:stderr])
    assert_rules_enabled(result, ["MD001", "MD002", "MD003"])
    assert_rules_disabled(result, ["MD004", "MD005", "MD006"])
  end

  def test_tag_exclusion_cli
    result = run_cli("-t ~headers -l")
    assert_equal(0, result[:status])
    assert_equal("", result[:stderr])
    assert_rules_disabled(result, ["MD001", "MD002", "MD003"])
    assert_rules_enabled(result, ["MD004", "MD005", "MD006"])
  end

  def test_rule_inclusion_config
    result = run_cli("-l", "", "mdlrc_enable_rules")
    assert_equal(0, result[:status])
    assert_equal("", result[:stderr])
    assert_rules_enabled(result, ["MD001", "MD002"], true)
  end

  def test_rule_exclusion_config
    result = run_cli("-l", "", "mdlrc_disable_rules")
    assert_equal(0, result[:status])
    assert_equal("", result[:stderr])
    assert_rules_disabled(result, ["MD001", "MD002"])
    assert_rules_enabled(result, ["MD003", "MD004"])
  end

  def test_tag_inclusion_config
    result = run_cli("-l", "", "mdlrc_enable_tags")
    assert_equal(0, result[:status])
    assert_equal("", result[:stderr])
    assert_rules_enabled(result, ["MD001", "MD002", "MD009", "MD010"])
    assert_rules_disabled(result, ["MD004", "MD005"])
  end

  def test_tag_exclusion_config
    result = run_cli("-l", "", "mdlrc_disable_tags")
    assert_equal(0, result[:status])
    assert_equal("", result[:stderr])
    assert_rules_enabled(result, ["MD004", "MD030", "MD032"])
    assert_rules_disabled(result, ["MD001", "MD005"])
  end
end
