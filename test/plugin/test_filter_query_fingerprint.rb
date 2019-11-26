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
    assert_equal(
      FP.fingerprint("SELECT SIN(3.14)"),
      "select sin(?)"
    )
  end

  test "Fingerprinter.fingerprint with `VALUES` function" do
    assert_equal(
      FP.fingerprint("INSERT INTO a_table (foo, bar) VALUES (1, 'aaa')"),
      "insert into a_table (foo, bar) values(?+)"
    )
    assert_equal(
      FP.fingerprint("INSERT INTO a_table (foo, bar) VALUES (1, 'aaa'), (2, 'bbb')"),
      "insert into a_table (foo, bar) values(?+)"
    )
    assert_equal(
      FP.fingerprint("INSERT INTO a_table (foo, bar) VALUE (1, 'aaa'), (2, 'bbb')"),
      "insert into a_table (foo, bar) value(?+)"
    )
    assert_equal(
      FP.fingerprint("SELECT my_function_values(1, 2)"),
      "select my_function_values(?, ?)"
    )
  end

  test "Fingerprinter.fingerprint with UNIONing similar queries" do
    assert_equal(
      FP.fingerprint("SELECT * FROM foo WHERE bar = 1 "\
                     "UNION SELECT * FROM foo WHERE bar = 2"),
      "select * from foo where bar = ? /*repeat union*/"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM foo WHERE bar = 1 "\
                     "UNION SELECT * FROM foo WHERE bar = 2 "\
                     "UNION SELECT * FROM foo WHERE bar = 3"),
      "select * from foo where bar = ? /*repeat union*/"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM foo WHERE bar = 1 "\
                     "UNION ALL SELECT * FROM foo WHERE bar = 2"),
      "select * from foo where bar = ? /*repeat union all*/"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM foo WHERE bar = 1 "\
                     "UNION SELECT * FROM foo WHERE bar = 2 "\
                     "UNION ALL SELECT * FROM foo WHERE bar = 3"),
      "select * from foo where bar = ? /*repeat union all*/"
    )

    assert_equal(
      FP.fingerprint("SELECT * FROM hoge INNER JOIN "\
                     "(SELECT * FROM foo WHERE bar = 1 "\
                     "UNION SELECT * FROM foo WHERE bar = 2) "\
                     "ON hoge.id = foo.hoge_id"),
      "select * from hoge inner join "\
      "(select * from foo where bar = ? /*repeat union*/) "\
      "on hoge.id = foo.hoge_id"
    )

    assert_equal(
      FP.fingerprint("SELECT MY_FUNC_SELECT (1) "\
                     "UNION SELECT (1)"),
      "select my_func_select (?) union select (?)"
    )
  end

  test "Fingerprinter.fingerprint with LIMIT clauses" do
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table LIMIT 10"),
      "select * from a_table limit ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table LIMIT 5, 10"),
      "select * from a_table limit ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table LIMIT 5,10"),
      "select * from a_table limit ?"
    )
    assert_equal(
      FP.fingerprint("SELECT * FROM a_table LIMIT 10 OFFSET 5"),
      "select * from a_table limit ?"
    )
  end

  test "Fingerprinter.fingerprint with `ORDER BY` clauses" do
    assert_equal(
      FP.fingerprint("SELECT * from a_table ORDER BY foo"),
      "select * from a_table order by foo"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table ORDER BY foo ASC"),
      "select * from a_table order by foo"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table ORDER BY foo DESC"),
      "select * from a_table order by foo desc"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table ORDER BY foo ASC, bar ASC"),
      "select * from a_table order by foo, bar"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table ORDER BY foo ASC, bar DESC, baz ASC"),
      "select * from a_table order by foo, bar desc, baz"
    )
    assert_equal(
      FP.fingerprint("SELECT * from a_table ORDER BY foo ASC, bar DESC, baz, quux ASC"),
      "select * from a_table order by foo, bar desc, baz, quux"
    )
  end

  test "Fingerprinter.fingerprint with `CALL` procedures" do
    assert_equal(
      FP.fingerprint("CALL func(@foo, @bar)"),
      "call func"
    )
    assert_equal(
      FP.fingerprint("  CALL func(@foo, @bar)"),
      "call func"
    )
  end

  test "Fingerprinter.fingerprint with multi-line comments" do
    assert_equal(
      FP.fingerprint("SELECT hoge /* comment */ FROM fuga"),
      "select hoge from fuga"
    )
    assert_equal(
      FP.fingerprint("SELECT hoge /* this is \n"\
                     "a multi-line comment */ FROM fuga"),
      "select hoge from fuga"
    )
    assert_equal(
      FP.fingerprint("SELECT hoge /* comment */ FROM /* another comment */ fuga"),
      "select hoge from fuga"
    )
  end

  test "Fingerprinter.fingerprint with multi-line comments followed by exclamation marks" do
    assert_equal(
      FP.fingerprint("SELECT /*! STRAIGHT_JOIN */ hoge from fuga, foo"),
      "select /*! straight_join */ hoge from fuga, foo"
    )
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QueryFingerprintFilter).configure(conf)
  end
end
