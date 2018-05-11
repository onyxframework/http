require "./param"
require "./named_tuple/from_param"
require "../ext/json/any/dig"

module Prism::Params
  # 8 MB ought to be enough for anybody.
  DEFAULT_MAX_BODY_SIZE = UInt64.new(8 * 1024 ** 2)

  # Extract then cast and validate params from a body limited to *limit* bytes. Returns `NamedTuple` of params.
  #
  # Will raise `InvalidParamTypeError`, `InvalidParamError` or `ParamNotFoundError` on failure.
  def self.parse_params(context, limit : UInt64 = DEFAULT_MAX_BODY_SIZE)
    raise "Call params macro before!"
  end

  private macro define_parse_params
    # Will copy context request body into `IO::Memory` and return this io, preserving original request body.
    private def self.copy_body(context, limit)
      if body = context.request.body
        string = body.gets(limit)
        context.request.body = IO::Memory.new.tap { |io| io << string; io.rewind }
        return IO::Memory.new.tap { |io| io << string; io.rewind }
      end
    end

    def self.parse_params(context, limit : UInt64 = DEFAULT_MAX_BODY_SIZE)
      %params = Param.new({} of String => Param)

      # 1. Extract params from path params. Does not support nested params
      {% if HTTP::Request.has_method?("path_params") %}
        context.request.path_params.try &.each do |key, value|
          {% begin %}
            case key
            {% for param in INTERNAL__PRISM_PARAMS %}
              when {{param[:name].id.stringify}}
                %params[{{param[:name].id.stringify}}] = Param.new(value)
            {% end %}
            end
          {% end %}
        end
      {% end %}

      # 2. Extract params from the request query. Supports nested params with following syntax: `"?user[email]=foo@example.com&user[password]=qwerty"`
      context.request.query_params.each do |key, value|
        {% begin %}
          case key
          {% for param in INTERNAL__PRISM_PARAMS %}
            {% if param[:parents] %}
              {% path = param[:parents] ? param[:parents][0] + "[" + (param[:parents][1..-1] + [param[:name]]).join("][") + "]" : param[:name] %}

              when {{path.id.stringify}}
                %params.deep_set({{(param[:parents] + [param[:name]]).map &.id.stringify}}, Param.new(value))
            {% else %}
              when {{param[:name].id.stringify}}
                %params[{{param[:name].id.stringify}}] = Param.new(value)
            {% end %}
          {% end %}
          end
        {% end %}
      end

      case context.request.headers["Content-Type"]?

      # 3. Extract params from the body with Content-Type set to "multipart/form-data". Supports nested params
      when /multipart\/form-data/
        copy = copy_body(context, limit)

        HTTP::FormData.parse(context.request) do |part|
          {% begin %}
            case part.name
            {% for param in INTERNAL__PRISM_PARAMS %}
              {% if param[:parents] %}
                {% path = param[:parents] ? param[:parents][0] + "[" + (param[:parents][1..-1] + [param[:name]]).join("][") + "]" : param[:name] %}

                when {{path.id.stringify}}
                  value = part.body.gets_to_end.gsub("\r\n", "").to_s
                  %params.deep_set({{(param[:parents] + [param[:name]]).map &.id.stringify}}, Param.new(value))
              {% else %}
                when {{param[:name].id.stringify}}
                  value = part.body.gets_to_end.gsub("\r\n", "").to_s
                  %params[{{param[:name].id.stringify}}] = Param.new(value)
              {% end %}
            {% end %}
            end
          {% end %}
        end

        context.request.body = copy

      # 4. Extract params from the body with Content-Type set to "application/x-www-form-urlencoded". Supports nested params
      when /application\/x-www-form-urlencoded/
        HTTP::Params.parse(copy_body(context, limit).not_nil!.gets_to_end) do |key, value|
          {% begin %}
            case key
            {% for param in INTERNAL__PRISM_PARAMS %}
              {% if param[:parents] %}
                {% path = param[:parents] ? param[:parents][0] + "[" + (param[:parents][1..-1] + [param[:name]]).join("][") + "]" : param[:name] %}

                when {{path.id.stringify}}
                  %params.deep_set({{(param[:parents] + [param[:name]]).map &.id.stringify}}, Param.new(value))
              {% else %}
                when {{param[:name].id.stringify}}
                  %params[{{param[:name].id.stringify}}] = Param.new(value)
              {% end %}
            {% end %}
            end
          {% end %}
        end

      # 5. Extract params from the body with Content-Type set to "application/json". Supports nested params
      when /application\/json/
        json = JSON.parse(copy_body(context, limit).not_nil!)
        {% for param in INTERNAL__PRISM_PARAMS %}
          value = json.dig?({{param[:parents] ? ((param[:parents] + [param[:name]]).map &.id.stringify) : [param[:name].id.stringify]}})

          # TODO: Extract raw types from JSON to avoid double-casting
          if value
            {% if param[:parents] %}
              %params.deep_set({{(param[:parents] + [param[:name]]).map &.id.stringify}}, Param.new(value.to_s))
            {% else %}
              %params[{{param[:name].id.stringify}}] = Param.new(value.to_s)
            {% end %}
          end
        {% end %}
      end

      {% for param in INTERNAL__PRISM_PARAMS %}
        {% _type = param[:type].is_a?(Generic) ? param[:type].type_vars.first.resolve : param[:type].resolve %}

        {% if _type != String || param[:validate] || param[:proc] %}
          %param = %params.dig?({{param[:parents] ? ((param[:parents] + [param[:name]]).map &.id.stringify) : [param[:name].id.stringify]}})

          if %param
            begin
              %value = {{_type.id}}.from_s(%param.value.as(String))

              validate_param({{param}}, %value)

              {% if param[:proc] %}
                %value = {{param[:proc].id}}.call(%value)
              {% end %}

              {% if param[:parents] %}
                %params.deep_set({{(param[:parents] + [param[:name]]).map &.id.stringify}}, Param.new(%value))
              {% else %}
                %params[{{param[:name].id.stringify}}] = Param.new(%value)
              {% end %}
            rescue ex : ArgumentError
              raise InvalidParamTypeError.new({{param[:name].id.stringify}}, {{_type.stringify}}, %param.value.as(String))
            end
          end
        {% end %}
      {% end %}

      ParamsTuple.from_param(%params)
    end
  end
end
