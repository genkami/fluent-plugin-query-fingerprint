require "helper"
require "fluent/plugin/filter_query_fingerprint.rb"

class QueryFingerprintFilterTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  test "dummy" do
    assert_equal(1 + 1, 2)
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QueryFingerprintFilter).configure(conf)
  end
end
