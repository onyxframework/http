require "http-params-serializable"
require "../../error"

module Onyx::HTTP::Endpoint
  # Define form params which would be deserialzed from the request body only if
  # its "Content-Type" header is "application/x-www-form-urlencoded". The serialization is powered by [`HTTP::Params::Serializable`](https://github.com/vladfaust/http-params-serializable).
  #
  # ## Options
  #
  # * `require` -- if set to `true`, will attempt to parse form params regardless
  # of the `"Content-Type"` header and return a parameter error otherwise; the `params.form`
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
  #     form do
  #       type user do
  #         type email : String?
  #         type username : String?
  #       end
  #     end
  #   end
  #
  #   def call
  #     if form = params.form
  #       pp! form.user.email
  #       pp! form.user.username
  #     end
  #   end
  # end
  # ```
  #
  # ```shell
  # > curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "user[email]=foo@example.com" http://localhost:5000/users/42
  # form.user.email    => "foo@example.com"
  # form.user.username => nil
  # ```
  #
  # If your endpoint expects form params only, then it can be simplified a bit:
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
  #     form require: true do
  #       type user do
  #         type email : String?
  #         type username : String?
  #       end
  #     end
  #   end
  #
  #   def call
  #     pp! params.form.user.email
  #     pp! params.form.user.username
  #   end
  # end
  # ```
  #
  # ```shell
  # > curl -X POST -d "user[email]=foo@example.com" http://localhost:5000/users/42
  # ```
  macro form(require required = false, &block)
    class FormError < Onyx::HTTP::Error(400)
      def initialize(message : String, @path : Array(String))
        super(message)
      end

      def payload
        {path: @path}
      end
    end

    struct Form
      include ::HTTP::Params::Serializable

      {% verbatim do %}
        macro type(argument, nilable = false, **options, &block)
          {% if block %}
            {% unless options.empty? %}
              @[::HTTP::Param({{**options}})]
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
              include ::HTTP::Params::Serializable

              {% if block.body.is_a?(Expressions) %}
                {% for expression in block.body.expressions %}
                  Form.{{expression}}
                {% end %}
              {% elsif block.body.is_a?(Call) %}
                Form.{{yield.id}}
              {% else %}
                {% raise "BUG: Unhandled block body type #{block.body.class_name}" %}
              {% end %}
            end
          {% elsif argument.is_a?(TypeDeclaration) %}
            {% unless options.empty? %}
              @[::HTTP::Param({{**options}})]
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
      getter! form  : Form
    {% else %}
      getter form  : Form?
    {% end %}

    def initialize(request : ::HTTP::Request)
      previous_def

      {% begin %}
        begin
          {% unless required %}
            if request.headers["Content-Type"]?.try &.=~ /^application\/x-www-form-urlencoded/
          {% end %}
            if body = request.body
              @form = Form.from_query(body.gets_to_end)
            else
              raise FormError.new("Missing request body", [] of String)
            end
          {% unless required %}
            end
          {% end %}
        rescue ex : ::HTTP::Params::Serializable::Error
          raise FormError.new("Form p" + ex.message.not_nil![1..-1], ex.path)
        end
      {% end %}
    end
  end
end
