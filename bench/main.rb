$LOAD_PATH.unshift(File.expand_path("../../", __FILE__))

require "benchmark"
require "fluent/env"
require "fluent/plugin/filter_query_fingerprint"

module FingerprintBenchamrker
  module_function

  NUM_QUERIES = 10000

  def benchmark
    Benchmark.bmbm do |x|
      x.report("simple select") do
        b("SELECT * FROM `a_database`.`a_table` WHERE `a_column` = 'a_value'")
      end
      x.report("large insert") do
        values = "(1, 'foo', true), " * 999 + "(1, 'foo', true)"
        b("INSERT INTO `a_database`.`a_table` (`column1`, `column2`, `column3`) VALUES " + values)
      end
      x.report("large select") do
        b %[
          SELECT * FROM /* this is
          a comment */ `a_database`.`a_table` AS `a` -- this is also a comment
          JOIN `a_database`.`another_table` AS `b`
          ON `a`.`id` = `b`.`a_id`
          WHERE `a`.`a_column` = 12345
          AND `b`.`another_column` LIKE 'foobar%'
          ORDER BY `a`.`foo` ASC, `b`.`bar` DESC
          LIMIT 10
          OFFSET 100
        ]
      end
    end
  end

  def b(query)
    NUM_QUERIES.times do
      Fluent::Plugin::QueryFingerprintFilter::Fingerprinter.fingerprint(query)
    end
  end
end

FingerprintBenchamrker.benchmark
