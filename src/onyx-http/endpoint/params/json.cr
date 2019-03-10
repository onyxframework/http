require "json"
require "../../error"

module Onyx::HTTP::Endpoint
  # Define JSON params which would be deserialized from the request body only if
  # its "Content-Type" header is "application/json". The serialization is powered by
  # stdlib's [`JSON::Serializable`](https://crystal-lang.org/api/latest/JSON/Serializable.html).
  #
  # ## Options
  #
  # * `require` -- if set to `true`, will attempt to parse JSON params regardless
  # of the `"Content-Type"` header and return a parameter error otherwise; the `params.json`
  # getter becomes non-nilable
  #
  # ## Example
  #
  # ```
  # struct UpdateUser
  #   include Onyx::HTTP::Endpoint
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
  #   include Onyx::HTTP::Endpoint
  #
  #   params do
  #     path do
  #       type id : Int32
  #     end
  #
  #     json require: true do
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
  #
  # ```shell
  # > curl -X POST -d '{"user":{"email":"foo@example.com"}}' http://localhost:5000/users/1
  # ```
  macro json(require required = false, &block)
    class JSONError < Onyx::HTTP::Error(400)
    end

    struct JSON
      include ::JSON::Serializable

      {% verbatim do %}
        macro type(argument, nilable = false, **options, &block)
          {% if block %}
            {% unless options.empty? %}
              @[::JSON::Field({{**options}})]
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
              include ::JSON::Serializable

              {% if block.body.is_a?(Expressions) %}
                {% for expression in block.body.expressions %}
                  JSON.{{expression}}
                {% end %}
              {% elsif block.body.is_a?(Call) %}
                JSON.{{yield.id}}
              {% else %}
                {% raise "BUG: Unhandled block body type #{block.body.class_name}" %}
              {% end %}
            end
          {% elsif argument.is_a?(TypeDeclaration) %}
            {% unless options.empty? %}
              @[::JSON::Field({{**options}})]
            {% end %}

            getter {{argument}}
          {% else %}
            {% raise "BUG: Unhandled argument type #{argument.class_name}" %}
          {% end %}
        end
      {% end %}

      {{yield.id}}
    end

    {% if required %}
      getter! json  : JSON
    {% else %}
      getter json  : JSON?
    {% end %}

    def initialize(request : HTTP::Request)
      previous_def

      {% begin %}
        begin
          {% unless required %}
            if request.headers["Content-Type"]?.try &.=~ /^application\/json/
          {% end %}
            if body = request.body
              @json = JSON.from_json(body.gets_to_end)
            else
              raise JSONError.new("Missing request body")
            end
          {% unless required %}
            end
          {% end %}
        rescue ex : ::JSON::MappingError
          raise JSONError.new(ex.message.not_nil!.lines.first)
        end
      {% end %}
    end
  end
end
