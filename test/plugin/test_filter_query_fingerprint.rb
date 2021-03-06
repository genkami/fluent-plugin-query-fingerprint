require "helper"
require "fluent/plugin/filter_query_fingerprint.rb"

class QueryFingerprintFilterTest < Test::Unit::TestCase
  FP = ::Fluent::Plugin::QueryFingerprintFilter::Fingerprinter

  setup do
    Fluent::Test.setup
  end

  sub_test_case "filter" do
    test "query transformation" do
      conf = %[
        query_key query
        fingerprint_key query_fingerprint
      ]
      d = create_driver(conf)
      d.run(default_tag: "input.access") do
        d.feed({"query" => "SELECT * FROM hoge WHERE fuga = 123"})
        d.feed({"query" => "SELECT * FROM `hoge1`.`fuga2` WHERE `piyo3` = 123"})
      end
      filtered = d.filtered_records
      assert_equal "select * from hoge where fuga = ?", filtered[0]["query_fingerprint"]
      assert_equal "select * from `hoge?`.`fuga?` where `piyo?` = ?", filtered[1]["query_fingerprint"]
    end

    test "query transformation with perserve_embedded_numbers enabled" do
      conf = %[
        query_key query
        fingerprint_key query_fingerprint
        preserve_embedded_numbers true
      ]
      d = create_driver(conf)
      d.run(default_tag: "input.access") do
        d.feed({"query" => "SELECT * FROM hoge WHERE fuga = 123"})
        d.feed({"query" => "SELECT * FROM `hoge1`.`fuga2` WHERE `piyo3` = 123"})
      end
      filtered = d.filtered_records
      assert_equal "select * from hoge where fuga = ?", filtered[0]["query_fingerprint"]
      assert_equal "select * from `hoge1`.`fuga2` where `piyo3` = ?", filtered[1]["query_fingerprint"]
    end
  end

  sub_test_case "configure" do
    test "missing query_key" do
      conf = %[
        fingerprint_key query_fingerprint
      ]
      assert_raise(Fluent::ConfigError) do
        create_driver(conf)
      end
    end

    test "missing fingerprint_key" do
      conf = %[
        query_key query
      ]
      assert_raise(Fluent::ConfigError) do
        create_driver(conf)
      end
    end
  end


  sub_test_case "Fingerprinter.fingerprint" do
    test "no side effect" do
      q = "SELECT * FROM hoge WHERE fuga = 1"
      FP.fingerprint(q)
      assert_equal(q, "SELECT * FROM hoge WHERE fuga = 1")
    end

    test "mysqldump" do
      assert_equal(
        FP.fingerprint("SELECT /*!40001 SQL_NO_CACHE */ * FROM `the_table`"),
        "mysqldump"
      )
    end

    test "percona-toolkit" do
      assert_equal(
        FP.fingerprint("REPLACE /*foo.bar:3/3*/ INTO checksum.checksum"),
        "percona-toolkit"
      )
    end

    test "admin command" do
      assert_equal(
        FP.fingerprint("administrator command: Ping"),
        "administrator command: ping"
      )
    end

    test "`USE`" do
      assert_equal(
        FP.fingerprint("USE `the_table`"),
        "use ?"
      )
    end

    test "double-quoted strings" do
      assert_equal(
        FP.fingerprint(%{SELECT "foo_bar"}),
        "select ?"
      )
    end

    test "escaped double-quotes" do
      assert_equal(
        FP.fingerprint(%{SELECT "foo_\\"bar\\""}),
        "select ?"
      )
    end

    test "single-quoted strings" do
      assert_equal(
        FP.fingerprint(%{SELECT 'foo_bar'}),
        "select ?"
      )
    end

    test "escaped single quotes" do
      assert_equal(
        FP.fingerprint(%{SELECT 'foo_\\'bar\\''}),
        "select ?"
      )
    end

    test "TRUE" do
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

    test "FALSE" do
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

    test "numbers" do
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

    test "numbers in identifiers" do
      assert_equal(
        FP.fingerprint("SELECT * FROM a_table0 WHERE a_value1 = 123"),
        "select * from a_table? where a_value? = ?"
      )
      assert_equal(
        FP.fingerprint("SELECT * FROM a_table0 WHERE a_value1 = 123",
                       preserve_embedded_numbers: true),
        "select * from a_table0 where a_value1 = ?"
      )
    end

    test "leading/trailing whitespaces" do
      assert_equal(
        FP.fingerprint("  \t\nSELECT * FROM a_table WHERE a_value = 123   \t\n"),
        "select * from a_table where a_value = ?"
      )
    end

    test "whitespaces" do
      assert_equal(
        FP.fingerprint("SELECT *\tFROM a_table  \n  \fWHERE\r\na_value = 123"),
        "select * from a_table where a_value = ?"
      )
    end

    test "NULLs" do
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

    test "`IN` operator" do
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

    test "`VALUES` function" do
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

    test "UNIONing similar queries" do
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

    test "LIMIT clauses" do
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

    test "`ORDER BY` clauses" do
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

    test "`CALL` procedures" do
      assert_equal(
        FP.fingerprint("CALL func(@foo, @bar)"),
        "call func"
      )
      assert_equal(
        FP.fingerprint("  CALL func(@foo, @bar)"),
        "call func"
      )
    end

    test "multi-line comments" do
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

    test "multi-line comments followed by exclamation marks" do
      assert_equal(
        FP.fingerprint("SELECT /*! STRAIGHT_JOIN */ hoge from fuga, foo"),
        "select /*! straight_join */ hoge from fuga, foo"
      )
    end

    test "one-line comments" do
      assert_equal(
        FP.fingerprint("SELECT * FROM hoge -- comment"),
        "select * from hoge"
      )
      assert_equal(
        FP.fingerprint("SELECT * FROM hoge -- comment\n"\
                       "WHERE fuga = 1"),
        "select * from hoge where fuga = ?"
      )
      assert_equal(
        FP.fingerprint("SELECT * FROM hoge # comment"),
        "select * from hoge"
      )
      assert_equal(
        FP.fingerprint("SELECT * FROM hoge # comment\n"\
                       "WHERE fuga = 1"),
        "select * from hoge where fuga = ?"
      )
    end

    test "unicode" do
      assert_equal(
        FP.fingerprint("SELECT * FROM hoge where value = 'ほげふが'"),
        "select * from hoge where value = ?"
      )
    end
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::QueryFingerprintFilter).configure(conf)
  end
end
