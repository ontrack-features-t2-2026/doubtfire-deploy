# frozen_string_literal: true

require 'minitest/autorun'
require 'pathname'

# Exercise the exact Ruby program passed to Rails by demo.sh. These doubles do
# not connect to a database or run Rails tasks; the API owns the scenario guard
# tests, while this suite checks that no bootstrap task can bypass that guard.
module BootstrapState
  class << self
    attr_accessor :events, :database, :sources, :guard_error, :task_error
  end
end

module Rails
  def self.root
    Pathname.new('/demo-api')
  end

  def self.application
    self
  end

  def self.load_tasks
    BootstrapState.events << :load_tasks
  end
end

class Time
  def self.zone
    self
  end
end

module DemoData
  class AllFeaturesScenario
    DATABASE_NAME = 'doubtfire-all-features-demo'

    def initialize(reference_time:)
      raise 'Missing reference time' unless reference_time.is_a?(Time)
    end

    def guard!
      BootstrapState.events << :guard
      raise BootstrapState.guard_error if BootstrapState.guard_error
    end
  end
end

module ActiveRecord
  class Base
    def self.connection
      self
    end

    def self.select_value(query)
      raise 'Unexpected query' unless query == 'SELECT DATABASE()'

      BootstrapState.events << :database_check
      BootstrapState.database
    end

    def self.data_sources
      BootstrapState.events << :inspect_sources
      BootstrapState.sources
    end
  end
end

module Rake
  class Task
    def self.[](name)
      new(name)
    end

    def initialize(name)
      @name = name
    end

    def invoke
      raise 'Test database was not excluded' unless ENV['SKIP_TEST_DATABASE'] == '1'

      BootstrapState.events << @name
      raise 'Task failed' if BootstrapState.task_error == @name
    end
  end
end

class BootstrapStrategyTest < Minitest::Test
  SCRIPT = File.read(File.join(__dir__, 'demo.sh'))
  SOURCE = SCRIPT.match(/<<'DEMO_BOOTSTRAP_RUBY'\n(.*?)\nDEMO_BOOTSTRAP_RUBY/m)&.captures&.first
  GUARDED_PREFIX = [:guard, :database_check, :load_tasks, :inspect_sources].freeze

  def setup
    BootstrapState.events = []
    BootstrapState.database = DemoData::AllFeaturesScenario::DATABASE_NAME
    BootstrapState.sources = []
    BootstrapState.guard_error = nil
    BootstrapState.task_error = nil
    @previous_skip_test_database = ENV.delete('SKIP_TEST_DATABASE')
  end

  def teardown
    if @previous_skip_test_database
      ENV['SKIP_TEST_DATABASE'] = @previous_skip_test_database
    else
      ENV.delete('SKIP_TEST_DATABASE')
    end
  end

  def run_bootstrap
    refute_nil SOURCE, 'The shell helper must contain the tested bootstrap program.'
    context = Object.new
    context.define_singleton_method(:require) do |path|
      raise 'Unexpected dependency' unless path.to_s == '/demo-api/lib/demo_data/all_features_scenario'

      true
    end
    context.instance_eval(SOURCE, 'demo.sh bootstrap')
  end

  def test_empty_database_loads_schema_only_after_guards_then_seeds
    run_bootstrap

    assert_equal GUARDED_PREFIX + ['db:schema:load', 'db:init', 'db:all_features_demo'], BootstrapState.events
    assert_equal '1', ENV['SKIP_TEST_DATABASE']
    assert_match(/run --rm -T/, SCRIPT, 'The runner must receive the bootstrap program through standard input.')
  end

  def test_existing_tables_are_migrated_without_schema_loading
    BootstrapState.sources = ['users', 'schema_migrations']
    run_bootstrap

    assert_equal GUARDED_PREFIX + ['db:migrate', 'db:init', 'db:all_features_demo'], BootstrapState.events
  end

  def test_even_a_view_or_partial_migration_is_not_an_empty_database
    [['existing_view'], ['schema_migrations']].each do |sources|
      BootstrapState.events = []
      BootstrapState.sources = sources
      run_bootstrap

      assert_equal GUARDED_PREFIX + ['db:migrate', 'db:init', 'db:all_features_demo'], BootstrapState.events
    end
  end

  def test_scenario_guard_failure_prevents_all_database_work
    BootstrapState.guard_error = 'Scenario safety guard refused this environment'

    assert_raises(RuntimeError) { run_bootstrap }
    assert_equal [:guard], BootstrapState.events
  end

  def test_connected_database_mismatch_prevents_schema_or_seed_tasks
    BootstrapState.database = 'another-database'

    capture_io { assert_raises(SystemExit) { run_bootstrap } }
    assert_equal [:guard, :database_check], BootstrapState.events
  end

  def test_failed_existing_migration_never_falls_back_to_schema_or_seeding
    BootstrapState.sources = ['schema_migrations', 'projects']
    BootstrapState.task_error = 'db:migrate'

    assert_raises(RuntimeError) { run_bootstrap }
    assert_equal GUARDED_PREFIX + ['db:migrate'], BootstrapState.events
  end

  def test_failed_schema_load_does_not_seed_partial_database
    BootstrapState.task_error = 'db:schema:load'

    assert_raises(RuntimeError) { run_bootstrap }
    assert_equal GUARDED_PREFIX + ['db:schema:load'], BootstrapState.events
  end
end
