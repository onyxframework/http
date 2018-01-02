module Prism::Params
  private macro cast(param, value)
    {%
      __type = param[:type].is_a?(Generic) ? param[:type].type_vars.first.resolve : param[:type].resolve
    %}

    %temp = uninitialized {{param[:type].id}}

    begin
      %temp = {{__type}}.from_s({{value.id}}.to_s)
    rescue ArgumentError
      {%
        expected_type = param[:type].is_a?(Generic) ? param[:type].type_vars.join(" or ") : param[:type].stringify
      %}

      raise InvalidParamTypeError.new(
        name: {{param[:name].id.stringify}},
        expected_type: {{expected_type}},
      )
    end

    validate({{param}}, %temp)

    {% if param[:proc] %}
      %temp = {{param[:proc].id}}.call(%temp) if %temp
    {% end %}

    _temp_params[{{param[:name]}}] = %temp
  end
end
