module Prism::Params
  private macro define_parse_params
    # Parse and validate params. Raise `InvalidParamTypeError` or `ParamNotFoundError` on failure.
    def self.parse_params(context)
      _temp_params = {
        {% for param in INTERNAL__PRISM_PARAMS %}
          {{param[:name]}} => nil.as({{INTERNAL__PRISM_PARAMS.map(&.[:type]).push("String").push("Nil").join(" | ").id}}),
        {% end %}
      }

      # 1. Extract params from path params
      {% if HTTP::Request.has_method?("path_params") %}
        context.request.path_params.try &.each do |key, value|
          {% begin %}
            case key
            {% for param in INTERNAL__PRISM_PARAMS %}
              when {{param[:name].id.stringify}}
                cast(value, {{param[:name]}}, {{param[:type]}})
            {% end %}
            end
          {% end %}
        end
      {% end %}

      # 2. Extract params from the request query
      context.request.query_params.to_h.each do |key, value|
        {% begin %}
          case key
          {% for param in INTERNAL__PRISM_PARAMS %}
            when {{param[:name].id.stringify}}
              cast(value, {{param[:name]}}, {{param[:type]}})
          {% end %}
          end
        {% end %}
      end

      # 3-5. Extract params from the body
      case context.request.headers["Content-Type"]?
      when /multipart\/form-data/
        HTTP::FormData.parse(context.request) do |part|
          {% begin %}
            case part.name
            {% for param in INTERNAL__PRISM_PARAMS %}
              when {{param[:name].id.stringify}}
                temp = part.body.gets_to_end.gsub("\r\n", "").to_s
                cast(temp, {{param[:name]}}, {{param[:type]}})
            {% end %}
            end
          {% end %}
        end
      when /application\/x-www-form-urlencoded/
        HTTP::Params.parse(context.request.body.not_nil!.gets_to_end) do |key, value|
          {% for param in INTERNAL__PRISM_PARAMS %}
            if key == {{param[:name].id.stringify}}
              cast(value, {{param[:name]}}, {{param[:type]}})
            end
          {% end %}
        end
      when /application\/json/
        json = JSON.parse(context.request.body.not_nil!)
        {% for param in INTERNAL__PRISM_PARAMS %}
          if value = json[{{param[:name].id.stringify}}]?
            cast(value, {{param[:name]}}, {{param[:type]}})
          end
        {% end %}
      end

      # Raise if a param is not found anywhere
      {% for param in INTERNAL__PRISM_PARAMS %}
        {% unless param[:nilable] %}
          raise ParamNotFoundError.new({{param[:name].id.stringify}}) unless _temp_params[{{param[:name]}}]?
        {% end %}
      {% end %}

      ParamsTuple.from(_temp_params)
    end
  end
end
