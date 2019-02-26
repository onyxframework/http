require "json"
require "../../error"

module Onyx::REST::Endpoint
  # Define JSON params which would be deserialized from the request body only if
  # its "Content-Type" header is "application/json". The serialization is powered by
  # stdlib's [`JSON::Serializable`](https://crystal-lang.org/api/latest/JSON/Serializable.html).
  #
  # ## Options
  #
  # * `require` -- whether to require the JSON params for this endpoints
  # (return `"400 Missing request body"` otherwise). If set to `true`,
  # then the `params#json` getter will be non-nilable
  # * `any_content_type` -- whether to try parsing the body regardless
  # of the `"Content-Type"` header
  #
  # If both `require` and `any_content_type` options are `true`, then the endpoint
  # will always try to parse the request body as a JSON and return 400 on error.
  #
  # If only `require` is `true` then the endpoint would expect the valid header,
  # erroring otherwise.
  #
  # ## Example
  #
  # ```
  # struct UpdateUser
  #   include Onyx::REST::Action
  #
  #   params do
  #     path do
  #       type id : Int32
  #     end
  #
  #     json do
  #       type user do
  #         type email : String?
  #         type username : String?
  #       end
  #     end
  #   end
  #
  #   def call
  #     if json = params.json
  #       pp! json.user.email
  #       pp! json.user.username
  #     end
  #   end
  # end
  # ```
  #
  # ```shell
  # > curl -X POST -H "Content-Type: application/json" -d '{"user":{"email":"foo@example.com"}}' http://localhost:5000/users/1
  # json.user.email    => "foo@example.com"
  # json.user.username => nil
  # ```
  #
  # If your endpoint expects JSON params only, then it can be simplified a bit:
  #
  # ```
  # struct UpdateUser
  #   include Onyx::REST::Action
  #
  #   params do
  #     path do
  #       type id : Int32
  #     end
  #
  #     json require: true, any_content_type: true do
  #       type user do
  #         type email : String?
  #         type username : String?
  #       end
  #     end
  #   end
  #
  #   def call
  #     pp! params.json.user.email
  #     pp! params.json.user.username
  #   end
  # end
  # ```
  macro json(require _require = false, any_content_type = false, &block)
    class JSONBodyError < Onyx::REST::Error(PARAMS_ERROR_CODE)
    end

    struct JSONBody
      include JSON::Serializable

      {% verbatim do %}
        macro type(argument, nilable = false, **options, &block)
          {% if block %}
            {% unless options.empty? %}
              @[JSON::Field({{**options}})]
            {% end %}

            {% if argument.is_a?(Path) %}
              {% raise "Cannot declare namespaced nested query parameter" if argument.names.size > 1 %}

              getter {{argument.names.first.underscore}} : {{argument.names.first.camelcase.id}}{{" | Nil".id if nilable}}
            {% elsif argument.is_a?(Call) %}
              getter {{argument.name.underscore}} : {{argument.name.camelcase.id}}{{" | Nil".id if nilable}}
            {% else %}
              {% raise "BUG: Unhandled argument type #{argument.class_name}" %}
            {% end %}

            {% if argument.is_a?(Path) %}
              struct {{argument.names.first.camelcase.id}}
            {% elsif argument.is_a?(Call) %}
              struct {{argument.name.camelcase.id}}
            {% end %}
              include JSON::Serializable

              {% if block.body.is_a?(Expressions) %}
                {% for expression in block.body.expressions %}
                  JSONBody.{{expression}}
                {% end %}
              {% elsif block.body.is_a?(Call) %}
                JSONBody.{{yield.id}}
              {% else %}
                {% raise "BUG: Unhandled block body type #{block.body.class_name}" %}
              {% end %}
            end
          {% elsif argument.is_a?(TypeDeclaration) %}
            {% unless options.empty? %}
              @[JSON::Field({{**options}})]
            {% end %}

            getter {{argument}}
          {% else %}
            {% raise "BUG: Unhandled argument type #{argument.class_name}" %}
          {% end %}
        end
      {% end %}

      {{yield.id}}
    end

    {% if _require %}
      getter! json  : JSONBody
    {% else %}
      getter json  : JSONBody?
    {% end %}

    def initialize(request : HTTP::Request)
      previous_def

      {% begin %}
        begin
          {% if any_content_type %}
            if true
          {% else %}
            if request.headers["Content-Type"]?.try &.=~ /^application\/json/
          {% end %}
            if body = request.body
              @json = JSONBody.from_json(body.gets_to_end)
            else
              {% if !any_content_type || _require %}
                raise JSONBodyError.new("Missing request body")
              {% end %}
            end
          end
        rescue ex : JSON::MappingError
          raise JSONBodyError.new(ex.message.not_nil!.lines.first)
        end
      {% end %}
    end
  end
end
