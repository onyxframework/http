module Prism::Params
  # A recursive param value holder.
  #
  # It cannot be set `private` due to `.from_param`, but is intended for internal use.

  # :nodoc:
  abstract struct AbstractParam
    getter name : String
    getter path : Array(String)

    def initialize(@name, @value, @path = [] of String)
    end

    def [](key)
      raise "Can not call AbstractParam#[] because its value is #{@value.class}" unless @value.is_a?(Hash)
      @value.as(Hash)[key]
    end

    def []?(key)
      raise "Can not call #AbstractParam[]? because its value is #{@value.class}" unless @value.is_a?(Hash)
      @value.as(Hash)[key]?
    end

    def []=(key, value)
      raise "Can not call AbstractParam#[]= because its value is #{@value.class}" unless @value.is_a?(Hash)
      @value.as(Hash)[key] = value
    end

    def deep_set(keys : Array, value, path = [] of String)
      raise "Can not call AbstractParam#deep_set because its value is #{@value.class}" unless @value.is_a?(Hash)
      raise ArgumentError.new("Keys must not be empty!") if keys.empty?

      if keys.size > 1
        key = keys.shift
        inner = self[key]? || (self[key] = self.class.new(
          key,
          {} of String => self,
          path,
        ))

        inner.deep_set(keys, value, path.dup.push(key))
      else
        self[keys.first] = self.class.new(keys.first, value, path)
      end
    end

    # The only body type having Arrays with types other than String is JSON,
    # and JSON uses `#deep_set` instead, therefore *value* argument is `String`.
    def deep_push(keys : Array, value : String)
      if existing_param = dig?(keys.dup)
        raise ArgumentError.new("Param with path #{keys} is already initialized with value different from Array(String)") unless existing_param.value.is_a?(Array(String))
        existing_param.value.as(Array(String)).push(value)
      else
        deep_set(keys, [value] of String)
      end
    end

    def dig?(keys)
      raise "Can not call AbstractParam#dig? because its value is #{@value.class}" unless @value.is_a?(Hash)
      raise ArgumentError.new("Keys must not be empty!") if keys.empty?

      if keys.size > 1
        key = keys.shift
        param = self[key]?

        return unless param

        param.dig?(keys) if param.value.is_a?(Hash)
      else
        self[keys.first]?
      end
    end
  end

  # :nodoc:
  struct StringParam < AbstractParam
    getter value : String

    def initialize(@name, @value, @path = [] of String)
    end
  end

  # :nodoc:
  struct JSONParam < AbstractParam
    getter value : JSON::Type

    def initialize(@name, @value, @path = [] of String)
    end
  end
end
