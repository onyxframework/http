module Prism::Params
  private macro cast(value, name, type _type, proc)
    {%
      __type = _type.is_a?(Generic) ? _type.type_vars.first.resolve : _type.resolve
    %}

    %temp = uninitialized {{_type.id}}

    begin
      %temp = {{__type}}.from_s({{value.id}}.to_s)
    rescue ArgumentError
      {%
        expected_type = _type.is_a?(Generic) ? _type.type_vars.join(" or ") : _type.stringify
      %}

      raise InvalidParamTypeError.new(
        name: {{name.id.stringify}},
        expected_type: {{expected_type}},
      )
    end

    validate({{name}}, %temp)

    {% if proc %}
      %temp = {{proc.id}}.call(%temp) if %temp
    {% end %}

    _temp_params[{{name}}] = %temp
  end
end
