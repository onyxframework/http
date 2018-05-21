struct Int
  # Initialize from *param*.
  #
  # ```
  # UInt8.from_param(<@value="2">) # => 2_u8
  # ```
  def self.from_param(param : Prism::Params::AbstractParam)
    {% begin %}
      case param.value
      {% for t in %w(String Int) %}
        when {{t.id}}
          {% for n in %w(8 16 32 64 128) %}
            {% if @type.name == "UInt" + n %}
              return param.value.as({{t.id}}).to_u{{n.id}}
            {% elsif @type.name == "Int" + n %}
              return param.value.as({{t.id}}).to_i{{n.id}}
            {% end %}
          {% end %}
      {% end %}
      when JSON::Any
        begin
          {% found = false %}
          {% for n in %w(8 16 32) %}
            {% if @type.name == "UInt" + n %}
              {% found = true %}
              return param.value.as(JSON::Any).as_i.to_u{{n.id}}
            {% end %}
          {% end %}
          {% if @type.name == "UInt64" %}
            return param.value.as(JSON::Any).as_i64.to_u64
          {% elsif @type.name == "UInt128" %}
            return param.value.as(JSON::Any).as_i64.to_u128
          {% elsif @type.name == "Int32" %}
            return param.value.as(JSON::Any).as_i
          {% elsif @type.name == "Int64" %}
            return param.value.as(JSON::Any).as_i64
          {% elsif !found %}
            {% raise "Unknown Int type #{@type}" %}
          {% end %}
        rescue ex : JSON::ParseException
          raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
        end
      else
        raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
      end
    {% end %}
  end
end
