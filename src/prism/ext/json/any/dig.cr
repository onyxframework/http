struct JSON::Any
  # Dig a `JSON::Any` value with *keys* path.
  #
  # ```
  # {"foo" => {"bar" => 42}}.to_json.dig?(["foo", "bar"]) # => 42
  # ```
  def dig?(keys : Enumerable)
    raise ArgumentError.new("Keys must not be empty!") if keys.empty?

    if keys.size > 1
      key = keys.shift
      value = self[key]?

      return unless value

      if value.is_a?(JSON::Any)
        value.dig?(keys)
      else
        raise ArgumentError.new("JSON is expected to have JSON::Any value at key #{key}")
      end
    else
      self[keys.first]?
    end
  end
end
