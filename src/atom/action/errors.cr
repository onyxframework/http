class Atom
  module Action
    # All errors defined in `Action.errors` macro will inheritr from this class.
    abstract class Error(Code) < Exception
      # The HTTP status code, extracted from `Code` type variable.
      #
      # ```
      # type UserNotFound(404)
      #
      # error = UserNotFound.new
      # error.code # => 404
      # ```
      getter code : Int32 = Code

      # The payload of this error. Will be nil if no error variables are defined.
      #
      # ```
      # type UserNotFound(404), id : Int32
      #
      # error = UserNotFound.new(42)
      # error.payload # => {id: 42}
      # ```
      abstract def payload : NamedTuple | Nil

      # :nodoc:
      protected def initialize(message : String)
        super(message)
      end
    end

    private macro define_error(declaration)
      {% if declaration.is_a?(Call) %}
        {% unless declaration.name == "type" %}
          {% raise <<-TEXT
            Expected error to be defined with `type` call.

            \e[31m-\e[39m️ Your code:

              errors do
                \e[31m#{declaration}\e[39m
              end

            \e[32m+\e[39m️ Valid code:

              errors do
                \e[32mtype NotFound(404)\e[39m
              end
            TEXT
          %}
        {% end %}

        {% unless declaration.args[0].is_a?(Generic) %}
          {% raise <<-TEXT
            Expected error definition to contain an HTTP status code.

            \e[31m-\e[39m️ Your code:

              errors do
                type #{declaration.args[0]}
              end

            \e[32m+\e[39m️ Valid code:

              errors do
                type #{declaration.args[0]}\e[32m(404)\e[39m
              end
            TEXT
          %}
        {% end %}

        {% unless declaration.args[0].type_vars.size == 1 && declaration.args[0].type_vars.first.is_a?(NumberLiteral) %}
          {% raise <<-TEXT
            Expected error definition to contain a single HTTP status code.

            \e[31m-\e[39m️ Your code:

              errors do
                type #{declaration.args[0].name}\e[31m(#{declaration.args[0].type_vars.join(", ").id})\e[39m
              end

            \e[32m+\e[39m️ Valid code:

              errors do
                type #{declaration.args[0].name}\e[32m(404)\e[39m
              end
            TEXT
          %}
        {% end %}

        {% if declaration.named_args %}
          {% raise <<-TEXT
            Named arguments are restricted in error definition.

            \e[31m-\e[39m️ Your code:

              errors do
                type #{declaration.args[0]}, \e[31m#{declaration.named_args[0]}\e[39m
              end

            \e[32m+\e[39m️ Valid code (note the space):

              errors do
                type #{declaration.args[0]}, \e[32m#{declaration.named_args[0].name} : #{declaration.named_args[0].value}\e[39m
              end
            TEXT
          %}
        {% end %}

        class {{declaration.args[0].name}} < Error({{declaration.args[0].type_vars[0]}})
          {% if declaration.args.size > 1 %}
            {% for arg, i in declaration.args[1..-1] %}
              {% if arg.is_a?(TypeDeclaration) %}
                {% if arg.var.stringify == "payload" %}
                  {% raise <<-TEXT
                    Cannot use 'payload' as a variable name in error definition.

                    \e[31m-\e[39m️ Your code:

                      errors do
                        type #{declaration.args[0]}, \e[31mpayload\e[39m : #{arg.type}
                      end

                    \e[32m+\e[39m️ Valid code:

                      errors do
                        type #{declaration.args[0]}, \e[32manother_name\e[39m : #{arg.type}
                      end
                    TEXT
                  %}
                {% end %}
                getter {{arg.var}} : {{arg.type}}{{" = #{arg.value}".id if arg.value}}
              {% else %}
                {% raise <<-TEXT
                  Expected variable declaration as an argument of error definition.

                  \e[31m-\e[39m️ Your code:

                    errors do
                      type #{declaration.args[0]}, \e[31m#{arg}\e[39m
                    end

                  \e[32m+\e[39m️ Valid code:

                    errors do
                      type #{declaration.args[0]}, \e[32mid : Int32\e[39m
                    end
                  TEXT
                %}
              {% end %}
            {% end %}

            def initialize(
              {% for arg, i in declaration.args[1..-1].reject(&.value) %}
                @{{arg.var}} : {{arg.type}},
              {% end %}
              {% for arg, i in declaration.args[1..-1].select(&.value) %}
                @{{arg.var}} : {{arg.type}} = {{arg.value}},
              {% end %}
              )
                {% if declaration.block %}
                  {{declaration.block.body}}
                {% else %}
                  super({{declaration.args[0].name.stringify.underscore.split("_").map(&.capitalize).join(" ")}})
                {% end %}
            end
          {% else %}
            def initialize
              {% if declaration.block %}
                {{declaration.block.body}}
              {% else %}
                super({{declaration.args[0].name.stringify.underscore.split("_").map(&.capitalize).join(" ")}})
              {% end %}
            end
          {% end %}

          def payload
            {% if declaration.args[1..-1].size > 0 %}
              {
                {% for arg, i in declaration.args[1..-1] %}
                  {{arg.var}}: {{arg.var}},
                {% end %}
              }
            {% else %}
              nil
            {% end %}
          end
        end
      {% else %}
        {% raise "Bug: unhandled declaration type in `define_error`: `#{declaration}`" %}
      {% end %}
    end

    # Optional errors definition macro.
    #
    # ```
    # errors do
    #   type UserNotFound(404)
    #
    #   # This error has variable `attributes` and custom block called on initialization
    #   type InvalidUser(409), attributes : Hash(String, String) do
    #     # All errors inherit from Exception, so `super` sets the error message
    #     super("User has invalid attributes: #{attributes}")
    #   end
    # end
    #
    # def call
    #   raise UserNotFound.new
    #   raise InvalidUser.new({"name" => "too short"})
    # rescue e : UserNotFound
    #   pp e.code    # => 404
    #   pp e.payload # => nil
    #   pp e.message # => nil
    # rescue e : InvalidUser
    #   pp e.code    # => 409
    #   pp e.payload # => {attributes: {"name" => "too short"}}
    #   pp e.message # => "User has invalid attributes: {\"name\" => \"too short\"}"
    # end
    # ```
    macro errors(&block)
      {% unless block && block.body %}
        {% raise <<-TEXT
          Expected `errors` macro to be called with a block.

          \e[32m+\e[39m️ Valid code:

            errors \e[32mdo
              type NotFound(404)
            end\e[39m
          TEXT
        %}
      {% end %}

      {% if block.body.is_a?(Call) %}
        define_error({{block.body}})
      {% elsif block.body.is_a?(Expressions) %}
        {% for exp in block.body.expressions %}
          define_error({{exp}})
        {% end %}
      {% else %}
        {% raise <<-TEXT
          Expected an `errors` macro call contain errors defintions.

          \e[31m-\e[39m️ Your code:

            errors do
              \e[31m#{yield.id}\e[39m
            end

          \e[32m+\e[39m️ Valid code:

            errors do
              \e[32mtype NotFound(404)\e[39m
            end
          TEXT
        %}
      {% end %}
    end
  end
end
