require "http/request"
require "json"
require "../ext/from_param"
require "../ext/json/any/dig"

module Prism::Params
  # 8 MB ought to be enough for anybody.
  DEFAULT_MAX_BODY_SIZE = UInt64.new(8 * 1024 ** 2)

  # Extract then cast and validate params from a body limited to *limit* bytes. Returns `NamedTuple` of params.
  #
  # Could raise `InvalidParamTypeError` or `ParamNotFoundError` on failure.
  def self.parse_params(context, limit : UInt64 = DEFAULT_MAX_BODY_SIZE)
    raise "Call #params macro before!"
  end

  private macro define_parse_params
    # Will copy context request body into `IO::Memory` and return this io, **preserving** original request body.
    def self.copy_body(context, limit)
      if body = context.request.body
        io = IO::Memory.new

        IO.copy(body, io, limit)
        IO.copy(io, body)

        body.rewind
        io.rewind

        return io
      end
    end

    def self.parse_params(context, limit : UInt64 = DEFAULT_MAX_BODY_SIZE, preserve_body = false)
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
          body = copy_body(context, limit) if preserve_body

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

          context.request.body = body if preserve_body

        # 4. Extract params from the body with Content-Type set to "application/x-www-form-urlencoded".
        # Supports both nested and array params.
        when /application\/x-www-form-urlencoded/
          body = copy_body(context, limit) if preserve_body

          HTTP::Params.parse(context.request.body.not_nil!.gets(limit).not_nil!) do |key, value|
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

          context.request.body = body if preserve_body

        # 5. Extract params from the body with Content-Type set to "application/json".
        # Supports both nested and array params.
        when /application\/json/
          body = copy_body(context, limit) if preserve_body
          json = JSON.parse(context.request.body.not_nil!.gets(limit).not_nil!)

          {% for param in INTERNAL__PRISM_PARAMS %}
            {% for key in param[:keys] %}
              {% path = param[:parents] ? (param[:parents] + [key]) : [key] %}

              # If JSON has `null` field, it is converted to `nil` by `JSON.parse`. So we convert that `nil` to `Null`. `"null"` value is considered to be String.
              #
              # E.g:
              #
              # ```
              # "{foo: null}"`   -> `params[:foo].is_a?(Null)   # => true
              # "{foo: "null"}"` -> `params[:foo].is_a?(String) # => true
              # ```
              json_value = json.dig?({{path}}).try do |v|
                {% if param[:type].is_a?(Union) && param[:type].types.any? { |t| t.stringify == "Null" } %}
                  break Null.new if v == nil
                {% end %}

                param = Param.new({{param[:name]}}, v.as(Param::Type){{", #{param[:parents]}".id if param[:parents]}})

                ({{param[:type].is_a?(Union) ? param[:type].types.reject { |t| t.stringify == "Null" }.join(" | ").id : param[:type].id}}).from_param(param)
              rescue InvalidParamTypeError
                raise InvalidParamTypeError.new(param.not_nil!, {{param[:type].stringify}})
              end

              if json_value != nil
                {% if param[:parents] %}
                  params.deep_set({{param[:parents] + [param[:name]]}}, json_value)
                {% else %}
                  params.deep_set({{[param[:name]]}}, json_value)
                {% end %}
              end
            {% end %}
          {% end %}

          context.request.body = body if preserve_body
        end
      end

      {% for param in INTERNAL__PRISM_PARAMS %}
        param = params.dig?({{param[:parents] ? (param[:parents] + [param[:name]]) : [param[:name]]}})

        if param
          begin
            value = ({{param[:type]}}).from_param(param)
          rescue ex : ArgumentError
            raise InvalidParamTypeError.new(param, {{param[:type].stringify}})
          end

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
