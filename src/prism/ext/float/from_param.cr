struct Float
  # Initialize from *param* value.
  #
  # ```
  # Float32.from_param(<@value="10.1">) # => 10.1_f32
  # ```
  def self.from_param(param : Prism::Params::AbstractParam)
    case param.value
    when String
      {% for n in %w(32 64) %}
        {% if @type.name == "Float" + n %}
          return param.value.as(String).to_f{{n.id}}
        {% end %}
      {% end %}
    when Float
      {% for n in %w(32 64) %}
        {% if @type.name == "Float" + n %}
          return param.value.as(Float).to_f{{n.id}}
        {% end %}
      {% end %}
    when JSON::Any
      begin
        {% if @type.name == "Float32" %}
          return param.value.as(JSON::Any).as_f32
        {% elsif @type.name == "Float64" %}
          return param.value.as(JSON::Any).as_f
        {% end %}
      rescue ex : JSON::ParseException
        raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
      end
    else
      raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
    end
  end
end
