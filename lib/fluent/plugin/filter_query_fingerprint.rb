#
# Copyright 2019- Genta Kamitani
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "fluent/plugin/filter"

module Fluent
  module Plugin
    class QueryFingerprintFilter < Fluent::Plugin::Filter
      Fluent::Plugin.register_filter("query_fingerprint", self)

      def filter(tag, time, record)
      end

      module Fingerprinter
        module_function

        def fingerprint(query, perserve_embedded_numbers: false)
          return "mysqldump" if query =~ %r#\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `#
          return "percona-toolkit" if query =~ %r#\*\w+\.\w+:[0-9]/[0-9]\*/#

          if match = /\A((?:INSERT|REPLACE)(?: IGNORE)?\s+INTO.+?VALUES\s*\(.*?\))\s*,\s*\(/im.match(query)
            query = match.captures.first
          end

          return query if query.gsub!(/\Ause \S+\Z/i, "use ?")

          query.gsub!(/\\["']/, "")
          query.gsub!(/".*?"/s, "?")
          query.gsub!(/'.*?'/s, "?")

          query.gsub!(/\btrue\b|\bfalse\b/i, "?")

          if perserve_embedded_numbers
            query.gsub!(/\b[0-9+-][0-9a-f.xb+-]*/, "?")
          else
            query.gsub!(/[0-9+-][0-9a-f.xb+-]*/, "?")
          end
          query.gsub!(/[xb.+-]\?/, "?")

          query.strip!
          query.gsub!(/[ \n\t\r\f]+/, " ")
          query.downcase!

          query.gsub!(/\bnull\b/i, "?")

          query.gsub!(/\b(in|values?)(?:[\s,]*\([\s?,]*\))+/, "\\1(?+)")

          query.gsub!(/\b(select\s.*?)(?:(\sunion(?:\sall)?)\s\1)+/, "\\1 /*repeat\\2*/")

          query.gsub!(/\blimit \?(?:, ?\?| offset \?)/, "limit ?")

          if query =~ /\border by/
            query.gsub!(/\G(.+?)\s+asc/, "\\1")
          end

          query
        end
      end
    end
  end
end
