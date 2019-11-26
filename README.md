# fluent-plugin-query-fingerprint

![](https://github.com/genkami/fluent-plugin-query-fingerprint/workflows/Test/badge.svg)

[Fluentd](https://fluentd.org/) filter plugin to normalize SQL queires.

This plugin does something like [pt-fingerprint](https://github.com/percona/percona-toolkit) to specific fields.

## Installation

### RubyGems

```
$ gem install fluent-plugin-query-fingerprint
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-query-fingerprint"
```

And then execute:

```
$ bundle
```

## Configuration

* **query_key** (string)(required): The field name that contain queries to be fingerprinted.
* **fingerprint_key** (string)(required): The field name to output fingerprint.
* **preserve_embedded_numbers** (boolean)(optional): If it is set to true, the filter does not replace numbers in identifiers. Deafults to false.

### Example Configuration

```
<filter pattern>
  @type query_fingerprint
  query_key sql
  fingerprint_key fingerprint
</filter>
```

## Copyright

* Copyright(c) 2019- Genta Kamitani
* License
  * Apache License, Version 2.0
