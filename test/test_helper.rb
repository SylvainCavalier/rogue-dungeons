ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # The 1% "unavoidable blow" on a dodge would make stubbed misses flaky
    # (test/services/siege_test.rb turns it back on where it is tested).
    setup { CombatService.unavoidable_hit_chance = 0 }
  end
end
