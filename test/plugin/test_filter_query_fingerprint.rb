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
      "administrator command: ping"
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
      "select ?"
    )
  end

  test "Fingerprinter.fingerprint with escaped double-quotes" do
    assert_equal(
      FP.fingerprint(%{SELECT "foo_\\"bar\\""}),
      "select ?"
    )
  end

  test "Fingerprinter.fingerprint with single-quoted strings" do
    assert_equal(
      FP.fingerprint(%{SELECT 'foo_bar'}),
      "select ?"
    )
  end

  test "Fingerprinter.fingerprint with escaped single quotes" do
    assert_equal(
      FP.fingerprint(%{SELECT 'foo_\\'bar\\''}),
      "select ?"
    )
  end

  test "Fingerprinter.fingerprint with TRUE" do
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = TRUE"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = true"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE true_column = true"),
      "select * from a_table where true_column = ?"
    )
  end

  test "Fingerprinter.fingerprint with FALSE" do
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = FALSE"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = false"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE false_column = false"),
      "select * from a_table where false_column = ?"
    )
  end

  test "Fingerprinter.fingerprint with numbers" do
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = 123"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = +123"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = -123"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = 0x12ab"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = 0b0011"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = 12.3"),
      "select * from a_table where a_value = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value = .1"),
      "select * from a_table where a_value = ?"
    )
  end

  test "Fingerprinter.fingerprint with numbers in identifiers" do
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table0 WHERE a_value1 = 123"),
      "select * from a_table? where a_value? = ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table0 WHERE a_value1 = 123",
                     perserve_embedded_numbers: true),
      "select * from a_table0 where a_value1 = ?"
    )
  end

  test "Fingerprinter.fingerprint with leading/trailing whitespaces" do
    assert_equal(
      FP.fingerprint("  \t\nSELECT * FROM a_table WHERE a_value = 123   \t\n"),
      "select * from a_table where a_value = ?"
    )
  end

  test "Fingerprinter.fingerprint with whitespaces" do
    assert_equal(
      FP.fingerprint("SELECT *\tFROM a_table  \n  \fWHERE\r\na_value = 123"),
      "select * from a_table where a_value = ?"
    )
  end

  test "Fingerprinter.fingerprint with NULLs" do
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value IS NULL"),
      "select * from a_table where a_value is ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value IS null"),
      "select * from a_table where a_value is ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE nullable IS null"),
      "select * from a_table where nullable is ?"
    )
  end

  test "Fingerprinter.fingerprint with `IN` operator" do
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value IN (1)"),
      "select * from a_table where a_value in(?+)"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table WHERE a_value IN (1, 2, 3)"),
      "select * from a_table where a_value in(?+)"
    )
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QueryFingerprintFilter).configure(conf)
  end
end
