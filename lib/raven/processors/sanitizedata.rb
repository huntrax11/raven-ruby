require 'raven/processor'
require 'json'

module Raven
  module Processor
    class SanitizeData < Processor

      MASK = '********'
      FIELDS_RE = /(authorization|password|passwd|secret)/i
      VALUES_RE = /^\d{16}$/

      def apply(value, key = nil, visited = [], &block)
        if value.is_a?(Hash)
          return "{...}" if visited.include?(value.__id__)
          visited += [value.__id__]

          value.each.reduce({}) do |memo, (k, v)|
            memo[k] = apply(v, k, visited, &block)
            memo
          end
        elsif value.is_a?(Array)
          return "[...]" if visited.include?(value.__id__)
          visited += [value.__id__]

          value.map do |value_|
            apply(value_, key, visited, &block)
          end
        elsif value.is_a?(String) && json_hash = JSON.parse(value) rescue nil
          return "[...]" if visited.include?(value.__id__)
          visited += [value.__id__]

          json_hash = json_hash.each.reduce({}) do |memo, (k, v)|
            memo[k] = apply(v, k, visited, &block)
            memo
          end

          json_hash.to_json
        else
          block.call(key, value)
        end
      end

      def sanitize(key, value)
        if !value.is_a?(String) || value.empty?
          value
        elsif VALUES_RE.match(clean_invalid_utf8_bytes(value)) || FIELDS_RE.match(key)
          MASK
        else
          clean_invalid_utf8_bytes(value)
        end
      end

      def process(data)
        apply(data) do |key, value|
          sanitize(key, value)
        end
      end

      private

      def clean_invalid_utf8_bytes(text)
        if RUBY_VERSION <= '1.8.7'
          text
        elsif RUBY_VERSION < '2.1.0'
          text.encode(
            'UTF-8',
            'binary',
            :invalid => :replace,
            :undef => :replace,
            :replace => ''
          )
        else
          text.encode(
            'UTF-8',
            :invalid => :replace,
            :undef => :replace,
            :replace => ''
          )
        end
      end
    end
  end
end
