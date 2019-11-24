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

  test "Fingerprinter.fingerprint with percona-toolkit" do
    assert_equal(
      FP.fingerprint("REPLACE /*foo.bar:3/3*/ INTO checksum.checksum"),
      "percona-toolkit"
    )
  end

  test "Fingerprinter.fingerprint with admin command" do
    assert_equal(
      FP.fingerprint("administrator command: Ping"),
      "administrator command: Ping"
    )
  end

  test "Fingerprinter.fingerprint with `USE`" do
    assert_equal(
      FP.fingerprint("USE `the_table`"),
      "use ?"
    )
  end

  test "Fingerprinter.fingerprint with double-quoted strings" do
    assert_equal(
      FP.fingerprint(%{SELECT "foo_bar"}),
      "SELECT ?"
    )
  end

  test "Fingerprinter.fingerprint with escaped double-quotes" do
    assert_equal(
      FP.fingerprint(%{SELECT "foo_\\"bar\\""}),
      "SELECT ?"
    )
  end

  test "Fingerprinter.fingerprint with single-quoted strings" do
    assert_equal(
      FP.fingerprint(%{SELECT 'foo_bar'}),
      "SELECT ?"
    )
  end

  test "Fingerprinter.fingerprint with escaped single quotes" do
    assert_equal(
      FP.fingerprint(%{SELECT 'foo_\\'bar\\''}),
      "SELECT ?"
    )
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QueryFingerprintFilter).configure(conf)
  end
end
