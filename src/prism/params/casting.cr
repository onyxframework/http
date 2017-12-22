module Prism::Params
  private macro cast(value, name, type _type)
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

    # OPTIMIZE
    {% param = INTERNAL__PRISM_PARAMS.find { |p| p[:name] == name } %}
    {% if param && (validation_proc = param[:validation]) %}
      begin
        {{validation_proc.id}}.call(%temp) || raise "Invalid"
      rescue
        raise InvalidParamError.new({{name.id.stringify}})
      end
    {% end %}

    _temp_params[{{name}}] = %temp
  end
end
