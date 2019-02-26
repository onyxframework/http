require "http-params-serializable"
require "../../error"

module Onyx::REST::Endpoint
  # Define form params which would be deserialzed from the request body only if
  # its "Content-Type" header is "application/x-www-form-urlencoded". The serialization is powered by [`HTTP::Params::Serializable`](https://github.com/vladfaust/http-params-serializable).
  #
  # ## Options
  #
  # * `require` -- whether to require the form params for this endpoints
  # (return `"400 Missing request body"` otherwise). If set to `true`,
  # then the `params#form` getter will be non-nilable
  # * `any_content_type` -- whether to try parsing the body regardless
  # of the `"Content-Type"` header
  #
  # If both `require` and `any_content_type` options are `true`, then the endpoint
  # will always try to parse the request body as a form and return 400 on error.
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
  #   include Onyx::REST::Action
  #
  #   params do
  #     path do
  #       type id : Int32
  #     end
  #
  #     form require: true, any_content_type: true do
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
  macro form(require _require = false, any_content_type = false, &block)
    class FormBodyError < Onyx::REST::Error(PARAMS_ERROR_CODE)
      def initialize(message : String, @path : Array(String))
        super(message)
      end

      def payload
        {path: @path}
      end
    end

    struct FormParams
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
                  FormParams.{{expression}}
                {% end %}
              {% elsif block.body.is_a?(Call) %}
                FormParams.{{yield.id}}
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

    {% if _require %}
      getter! form  : FormParams
    {% else %}
      getter form  : FormParams?
    {% end %}

    def initialize(request : ::HTTP::Request)
      previous_def

      {% begin %}
        begin
          {% if any_content_type %}
            if true
          {% else %}
            if request.headers["Content-Type"]?.try &.=~ /^application\/x-www-form-urlencoded/
          {% end %}
            if body = request.body
              @form = FormParams.from_query(body.gets_to_end)
            else
              {% if !any_content_type || _require %}
                raise FormBodyError.new("Missing request body", [] of String)
              {% end %}
            end
          end
        rescue ex : ::HTTP::Params::Serializable::Error
          raise FormBodyError.new("Form p" + ex.message.not_nil![1..-1], ex.path)
        end
      {% end %}
    end
  end
end
