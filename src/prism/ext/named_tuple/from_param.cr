module Prism::Params
  # Converts `Prism::Param` to a `NamedTuple`. Intended for private use only, so

  # :nodoc:
  def NamedTuple.from_param(param : Prism::Params::AbstractParam)
    {% begin %}
      NamedTuple.new(
        {% for key, value in T %}
          {% if value < NamedTuple || (value.union? && value.union_types.first < NamedTuple) %}
            {{key.stringify}}: (if value = param["{{key}}"]?
              if value.value.is_a?(Hash)
                {% if value < NamedTuple %}
                  {{value}}.from_param(value)
                {% else %}
                  {{value.union_types.first}}.from_param(value)
                {% end %}
              else
                raise Prism::Params::InvalidParamTypeError.new(param, "Object")
              end
            else
              {% nilable = (value.union? && value.union_types.any? { |t| t.name == "Nil" }) %}

              {% unless nilable %}
                raise Prism::Params::ParamNotFoundError.new(Prism::Params::StringParam.new({{key.stringify}}, "", param.path))
              {% end %}
            end),
          {% else %}
            {{key.stringify}}: (if value = param["{{key}}"]?
              {% _type = value.union? ? value.union_types.reject { |t| t.name == "Nil" }.first : value %}

              # raise Prism::Params::InvalidParamTypeError.new(param, {{(value.union? ? value.union_types.join(" or ") : value.stringify)}}) unless value.value.is_a?({{_type.id}})

              value.value.as({{_type}})
            else
              {% nilable = value.union? ? value.union_types.any? { |t| t.name == "Nil" } : value.is_a?(NilLiteral) %}

              {% unless nilable %}
                raise Prism::Params::ParamNotFoundError.new(Prism::Params::StringParam.new({{key.stringify}}, "", param.path))
              {% end %}
            end),
          {% end %}
        {% end %}
      )
    {% end %}
  end
end
