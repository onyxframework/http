module Prism::Params
  # A recursive param value holder.
  abstract struct AbstractParam
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

    def deep_set(keys : Array, value : self)
      raise "Can not call AbstractParam#deep_set because its value is #{@value.class}" unless @value.is_a?(Hash)
      raise ArgumentError.new("Keys must not be empty!") if keys.empty?

      if keys.size > 1
        key = keys.shift
        inner = self[key]? || (self[key] = self.class.new({} of String => self))

        inner.deep_set(keys, value)
      else
        self[keys.first] = value
      end
    end

    def dig?(keys)
      raise "Can not call AbstractParam#dig? because its value is #{@value.class}" unless @value.is_a?(Hash)
      raise ArgumentError.new("Keys must not be empty!") if keys.empty?

      if keys.size > 1
        key = keys.shift
        value = self[key]?

        return unless value

        value.dig?(keys) if value.value.is_a?(Hash)
      else
        self[keys.first]?
      end
    end
  end
end
