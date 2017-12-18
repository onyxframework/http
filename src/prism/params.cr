require "./ext/from_s"
require "./ext/json/lexer"
require "json"

module Prism
  # Request params access and validation module.
  #
  # Extracts params from (nearly) all possible sources and casts them accordingly (invoking `Type.from_s`) into a `NamedTuple`.
  #
  # ```
  # require "prism/action/params"
  #
  # class SimpleAction
  #   include Prism::Params
  #
  #   params do
  #     param :foo, Int32?
  #     param :name, String, validate: ->(name : String?) { name.size >= 3 }
  #     param "kebab-case-time", Time?
  #   end
  #
  #   def self.call(context)
  #     params = parse_params(context)
  #
  #     p params[:foo].class
  #     # => Int32?
  #
  #     p params[:name].class
  #     # => String
  #
  #     p params["kebab-case-time"].class
  #     # => Time?
  #   end
  # end
  # ```
  #
  # NOTE: Params can be accessed both by `String` and `Symbol` keys.
  #
  # Params parsing order (latter rewrites previous):
  #
  # 1. Path params (only if `"prism/ext/http/request/path_params"` is required **before**)
  # 2. Request query params
  # 3. Multipart form data (only if `"Content-Type"` is `"multipart/form-data"`)
  # 4. Body params (only if `"Content-Type"` is `"application/x-www-form-urlencoded"`)
  # 5. JSON body (only if `"Content-Type"` is `"application/json"`)
  #
  # NOTE: If `"Content-Type"` header is  `"application/x-www-form-urlencoded"` or `"application/json"`, the request body will be tried to read (and it's a known fact that it can be read only once). If used in `Prism::Action`, make sure to call `Prism::Action#copy_body` before.
  #
  # If you want to implement your own type cast, extend it with `.from_s` method (see `Time.from_s` for example).
  #
  # If included into `Prism::Action`, will automatically inject `parse_params` into `Action#before` callback:
  #
  # ```
  # require "prism/action"
  # require "prism/action/params"
  #
  # struct MyPrismAction < Prism::Action
  #   include Params
  #
  #   params do
  #     param :id, Int32
  #   end
  #
  #   def call
  #     p params[:id].class # => Int32
  #   end
  # end
  # ```
  module Params
    # An **essential** params definition block.
    #
    # ```
    # params do
    #   param :id, Int32
    # end
    # ```
    macro params(&block)
      REST___PARAMS = [] of NamedTuple(
        name: Symbol,
        type: String,
        nilable: Bool,
        validation: Proc?
      )

      {{yield}}

      define_params_tuple
      define_parse_params
    end

    # Define a single param. Must be called within the `#params` block.
    #
    # **Arguments:**
    #
    # - *name* declares an access key for the `params` tuple
    # - *type* defines a type which the param must be casted to, otherwise validation will fail (i.e. "foo" won't cast to `Int32`)
    # - *:nilable* option declares if this param is nilable (the same effect is achieved with nilable *type*, i.e. `Int32?`)
    # - *validate* option accepts a `Proc` which must return truthy value for the param to pass validation
    #
    # NOTE: If a param is nilable, but is present and of invalid type, an `InvalidParamTypeError` will be raised.
    #
    # ```
    # params do
    #   param :id, Int32, validate: ->(id : Int32) { id > 0 }
    #   param :name, String?             # => Nilable
    #   param :age, Int32, nilable: true # => Nilable as well
    # end
    # ```
    macro param(name, type _type, **options)
      {%
        nilable = if options[:nilable] == nil
                    "#{_type}".includes?("?") || "#{_type}".includes?("Nil")
                  else
                    options[:nilable]
                  end

        REST___PARAMS.push({
          name:       name,
          type:       _type,
          nilable:    nilable,
          validation: options[:validate],
        })
      %}
    end

    private macro define_params_tuple
      alias ParamsTuple = NamedTuple(
        {% for param in REST___PARAMS %}
          "{{param[:name].id}}": {{param[:type].id}}
        {% end %}
      )
    end

    private macro define_parse_params
      # Parse and validate params. Raise `InvalidParamTypeError` or `ParamNotFoundError` on failure.
      def self.parse_params(context)
        _temp_params = {
          {% for param in REST___PARAMS %}
            {{param[:name]}} => nil.as({{REST___PARAMS.map(&.[:type]).push("String").push("Nil").join(" | ").id}}),
          {% end %}
        }

        # 1. Extract params from path params
        {% if HTTP::Request.has_method?("path_params") %}
          context.request.path_params.try &.each do |key, value|
            {% begin %}
              case key
              {% for param in REST___PARAMS %}
                when {{param[:name].id.stringify}}
                  cast_param_to_temp(value, {{param[:name]}}, {{param[:type]}})
              {% end %}
              end
            {% end %}
          end
        {% end %}

        # 2. Extract params from the request query
        context.request.query_params.to_h.each do |key, value|
          {% begin %}
            case key
            {% for param in REST___PARAMS %}
              when {{param[:name].id.stringify}}
                cast_param_to_temp(value, {{param[:name]}}, {{param[:type]}})
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
              {% for param in REST___PARAMS %}
                when {{param[:name].id.stringify}}
                  temp = part.body.gets_to_end.gsub("\r\n", "").to_s
                  cast_param_to_temp(temp, {{param[:name]}}, {{param[:type]}})
              {% end %}
              end
            {% end %}
          end
        when /application\/x-www-form-urlencoded/
          HTTP::Params.parse(context.request.body.not_nil!.gets_to_end) do |key, value|
            {% for param in REST___PARAMS %}
              if key == {{param[:name].id.stringify}}
                cast_param_to_temp(value, {{param[:name]}}, {{param[:type]}})
              end
            {% end %}
          end
        when /application\/json/
          json = JSON.parse(context.request.body.not_nil!)
          {% for param in REST___PARAMS %}
            if value = json[{{param[:name].id.stringify}}]?
              cast_param_to_temp(value, {{param[:name]}}, {{param[:type]}})
            end
          {% end %}
        end

        # Raise if a param is not found anywhere
        {% for param in REST___PARAMS %}
          {% unless param[:nilable] %}
            raise ParamNotFoundError.new({{param[:name].id.stringify}}) unless _temp_params[{{param[:name]}}]?
          {% end %}
        {% end %}

        ParamsTuple.from(_temp_params)
      end
    end

    private macro cast_param_to_temp(value, name, type _type)
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
      {% param = REST___PARAMS.find { |p| p[:name] == name } %}
      {% if param && (validation_proc = param[:validation]) %}
        begin
          {{validation_proc.id}}.call(%temp) || raise "Invalid"
        rescue
          raise InvalidParamError.new({{name.id.stringify}})
        end
      {% end %}

      _temp_params[{{name}}] = %temp
    end

    class InvalidParamTypeError < Exception
      getter name
      getter expected_type

      MESSAGE_TEMPLATE = "Parameter \"%{name}\" is expected to be %{type}"

      def initialize(@name : String, @expected_type : String)
        super(MESSAGE_TEMPLATE % {
          name: @name,
          type: @expected_type,
        })
      end
    end

    class ParamNotFoundError < Exception
      getter name

      MESSAGE_TEMPLATE = "Parameter \"%{name}\" is missing"

      def initialize(@name : String)
        super(MESSAGE_TEMPLATE % {
          name: @name,
        })
      end
    end

    class InvalidParamError < Exception
      getter name

      MESSAGE_TEMPLATE = "Parameter \"%{name}\" is invalid"

      def initialize(@name : String)
        super(MESSAGE_TEMPLATE % {
          name: @name,
        })
      end
    end
  end
end
