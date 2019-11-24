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

  test "Fingerprinter.fingerprint with TRUE" do
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = TRUE"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = true"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where true_column = true"),
      "SELECT * from a_table where true_column = ?"
    )
  end

  test "Fingerprinter.fingerprint with FALSE" do
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = FALSE"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = false"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where false_column = false"),
      "SELECT * from a_table where false_column = ?"
    )
  end

  test "Fingerprinter.fingerprint with numbers" do
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = 123"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = +123"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = -123"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = 0x12ab"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = 0b0011"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = 12.3"),
      "SELECT * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table where a_value = .1"),
      "SELECT * from a_table where a_value = ?"
    )
  end

  test "Fingerprinter.fingerprint with numbers in identifiers" do
    assert_equal(
      FP.fingerprint("SELECT * from a_table0 where a_value1 = 123"),
      "SELECT * from a_table? where a_value? = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table0 where a_value1 = 123",
                     perserve_embedded_numbers: true),
      "SELECT * from a_table0 where a_value1 = ?"
    )
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QueryFingerprintFilter).configure(conf)
  end
end
