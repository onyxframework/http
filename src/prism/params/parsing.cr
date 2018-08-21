require "http/request"
require "json"
require "../ext/from_param"
require "../ext/json/any/dig"

module Prism::Params
  # 8 MB ought to be enough for anybody.
  DEFAULT_MAX_BODY_SIZE = UInt64.new(8 * 1024 ** 2)

  # Extract then cast and validate params from a body limited to *limit* bytes. Returns `NamedTuple` of params.
  #
  # Could raise `InvalidParamTypeError`, `InvalidParamError` or `ParamNotFoundError` on failure.
  def self.parse_params(context, limit : UInt64 = DEFAULT_MAX_BODY_SIZE)
    raise "Call #params macro before!"
  end

  private macro define_parse_params
    def self.parse_params(context, limit : UInt64 = DEFAULT_MAX_BODY_SIZE)
      params = Param.new("root", {} of String => Param)

      # 1. Extract params from path params.
      # Does not support neither nested nor array params.
      #
      # NOTE: It only extracts params with the same key as the param's name (e.g. `param float_value` will look for `"float_value"` only, not for `"floatValue"`)
      {% if HTTP::Request.has_method?("path_params") && INTERNAL__PRISM_PARAMS.any? { |param| !param[:parents] } %}
        context.request.path_params.try &.each do |key, value|
          {% begin %}
            case key
            {% for param in INTERNAL__PRISM_PARAMS.reject { |param| param[:parents] } %}
              when {{param[:name]}}
                params.deep_set({{[param[:name]]}}, value)
            {% end %}
            end
          {% end %}
        end
      {% end %}

      # 2. Extract params from the request query.
      #
      # Supports both nested and array params with following syntax:
      #
      # * Nested: `"?user[email]=foo@example.com&user[password]=qwerty"`.
      # * Array: `"?foo[]=42&foo[]=43"`.
      # * Mixed: `"?article[tags][]=foo&article[tags][]=bar"`
      #
      # NOTE: It doesn't support array of objects (`"?articles[][tags]=foo&articles[][tags]=bar"`)
      context.request.query_params.each do |key, value|
        {% begin %}
          case key
          {% for param in INTERNAL__PRISM_PARAMS %}
            {% for key in param[:keys] %}
              {% if param[:parents] %}
                {% path = param[:parents] ? param[:parents][0] + "[" + (param[:parents][1..-1] + [key]).join("][") + "]" : key %}

                {% if param[:array] %}
                  when {{(path + "[]")}}
                    params.deep_push({{(param[:parents] + [param[:name]])}}, value)
                {% else %}
                  when {{path}}
                    params.deep_set({{param[:parents] + [param[:name]]}}, value)
                {% end %}
              {% else %}
                {% if param[:array] %}
                  when {{key + "[]"}}
                    params.deep_push({{[param[:name]]}}, value)
                {% else %}
                  when {{key}}
                    params.deep_set({{[param[:name]]}}, value)
                {% end %}
              {% end %}
            {% end %}
          {% end %}
          end
        {% end %}
      end

      if context.request.body
        case context.request.headers["Content-Type"]?

        # 3. Extract params from the body with Content-Type set to "multipart/form-data".
        # Supports both nested and array params.
        when /multipart\/form-data/
          HTTP::FormData.parse(context.request) do |part|
            {% begin %}
              case part.name
              {% for param in INTERNAL__PRISM_PARAMS %}
                {% for key in param[:keys] %}
                  {% if param[:parents] %}
                    {% path = param[:parents] ? param[:parents][0] + "[" + (param[:parents][1..-1] + [key]).join("][") + "]" : key %}

                    {% if param[:array] %}
                      when {{path + "[]"}}
                        value = part.body.gets_to_end.gsub("\r\n", "").to_s
                        params.deep_push({{param[:parents] + [param[:name]]}}, value)
                    {% else %}
                      when {{path.id.stringify}}
                        value = part.body.gets_to_end.gsub("\r\n", "").to_s
                        params.deep_set({{param[:parents] + [param[:name]]}}, value)
                    {% end %}
                  {% else %}
                    {% if param[:array] %}
                      when {{key}}
                        value = part.body.gets_to_end.gsub("\r\n", "").to_s
                        params.deep_push([{{param[:name]}}], value)
                    {% else %}
                      when {{key}}
                        value = part.body.gets_to_end.gsub("\r\n", "").to_s
                        params.deep_set([{{param[:name]}}], value)
                    {% end %}
                  {% end %}
                {% end %}
              {% end %}
              end
            {% end %}
          end

          context.request.body.not_nil!.rewind

        # 4. Extract params from the body with Content-Type set to "application/x-www-form-urlencoded".
        # Supports both nested and array params.
        when /application\/x-www-form-urlencoded/
          HTTP::Params.parse(context.request.body.not_nil!.gets_to_end) do |key, value|
            {% begin %}
              case key
              {% for param in INTERNAL__PRISM_PARAMS %}
                {% for key in param[:keys] %}
                  {% if param[:parents] %}
                    {% path = param[:parents] ? param[:parents][0] + "[" + (param[:parents][1..-1] + [key]).join("][") + "]" : key %}

                    {% if param[:array] %}
                      when {{path + "[]"}}
                        params.deep_push({{param[:parents] + [param[:name]]}}, value)
                    {% else %}
                      when {{path.id.stringify}}
                        params.deep_set({{param[:parents] + [param[:name]]}}, value)
                    {% end %}
                  {% else %}
                    {% if param[:array] %}
                      when {{key + "[]"}}
                        params.deep_push({{[param[:name]]}}, value)
                    {% else %}
                      when {{key}}
                        params.deep_set({{[param[:name]]}}, value)
                    {% end %}
                  {% end %}
                {% end %}
              {% end %}
              end
            {% end %}
          end

          context.request.body.not_nil!.rewind

        # 5. Extract params from the body with Content-Type set to "application/json".
        # Supports both nested and array params.
        when /application\/json/
          json = JSON.parse(context.request.body.not_nil!.gets_to_end)

          {% for param in INTERNAL__PRISM_PARAMS %}
            {% for key in param[:keys] %}
              {%
                _type = if param[:type].is_a?(Union)
                          ("(" + param[:type].types.reject { |t| "#{t}" == "::Nil" }.join(" | ") + ")").id
                        elsif param[:type].is_a?(Generic)
                          if param[:type].name.stringify == "Array"
                            param[:type].id
                          end
                        else
                          param[:type].resolve
                        end

                path = param[:parents] ? (param[:parents] + [key]) : [key]
              %}

              json_value = json.dig?({{path}}).try do |v|
                {{_type.id}}.from_param(Param.new({{param[:name]}}, v.as(Param::Type), {{path}}))
              end

              if json_value
                {% if param[:parents] %}
                  params.deep_set({{param[:parents] + [param[:name]]}}, json_value)
                {% else %}
                  params.deep_set({{[param[:name]]}}, json_value)
                {% end %}
              end
            {% end %}
          {% end %}

          context.request.body.not_nil!.rewind
        end
      end

      {% for param in INTERNAL__PRISM_PARAMS %}
        {%
          _type = if param[:type].is_a?(Union)
                    param[:type].types.reject { |t| "#{t}" == "::Nil" }.join(" | ").id
                  elsif param[:type].is_a?(Generic)
                    if param[:type].name.stringify == "Array"
                      param[:type].id
                    end
                  else
                    param[:type].resolve
                  end
        %}

        param = params.dig?({{param[:parents] ? (param[:parents] + [param[:name]]) : [param[:name]]}})

        if param
          begin
            value = if param.value.is_a?({{_type.id}})
              param.value
            else
              {{_type.id}}.from_param(param)
            end
          rescue ex : ArgumentError
            raise InvalidParamTypeError.new(param, {{_type.stringify}})
          end

          {% if param[:validate] %}
            begin
              validate({{param[:validate]}}, value.as({{_type.id}}).not_nil!) if value
            rescue ex : Validation::Error
              raise InvalidParamError.new(param, ex.message)
            end
          {% end %}

          {% if param[:proc] %}
            begin
              value = {{param[:proc].id}}.call(value.as({{_type.id}}).not_nil!) if value
            rescue ex : Exception
              raise ProcError.new(param, ex.message)
            end
          {% end %}

          if value != param.value
            {% if param[:parents] %}
              params.deep_set({{param[:parents] + [param[:name]]}}, value.as(Param::Type))
            {% else %}
              params.deep_set({{[param[:name]]}}, value.as(Param::Type))
            {% end %}
          end
        end
      {% end %}

      ParamsTuple.from_param(params)
    end
  end
end
