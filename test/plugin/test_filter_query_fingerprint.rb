require "helper"
require "fluent/plugin/filter_query_fingerprint.rb"

class QueryFingerprintFilterTest < Test::Unit::TestCase
  FP = ::Fluent::Plugin::QueryFingerprintFilter::Fingerprinter

  setup do
    Fluent::Test.setup
  end

  test "Fingerprinter.fingerprint with mysqldump" do
    assert_equal(
      FP.fingerprint("SELECT /*!40001 SQL_NO_CACHE */ * FROM `the_table`"),
      "mysqldump"
    )
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QueryFingerprintFilter).configure(conf)
  end
end
