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

        def fingerprint(query)
          return "mysqldump" if query =~ %r#\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `#
          return "percona-toolkit" if query =~ %r#\*\w+\.\w+:[0-9]/[0-9]\*/#

          return query if query.gsub!(/\Ause \S+\Z/i, "use ?")

          query.gsub!(/\\["']/, "")
          query.gsub!(/".*?"/s, "?")
          query.gsub!(/'.*?'/s, "?")

          query.gsub!(/\btrue\b|\bfalse\b/i, "?")
          query
        end
      end
    end
  end
end
