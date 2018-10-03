require "http/server"
require "json"
require "callbacks"
require "params"
require "./action/*"

module Prism
  # A callable HTTP action with [Callbacks](https://github.com/vladfaust/callbacks.cr)
  # and [Params](https://github.com/vladfaust/params.cr) included.
  #
  # Params have special handy definition syntax, as seen in the example below:
  #
  # ```
  # struct MyAction
  #   include Prism::Action
  #
  #   params do
  #     type id : Int32
  #     type foo : Array(String) | Nil
  #     type user, nilable: true do
  #       type name : String
  #       type email : String?
  #     end
  #   end
  #
  #   def call
  #     # Will put the text into the response body
  #     text("id = #{id}, foo = #{foo.join(", ")}, user name = #{user.not_nil!.name}")
  #   end
  #
  #   after do
  #     p "MyAction has run successfully"
  #   end
  # end
  #
  # MyAction.call(env)
  # # => "MyAction has run successfully"
  # ```
  #
  # NOTE: Params errors aren't rescued by default, so you should define your own `ParamsErrorHandler` to handle this.
  #
  # NOTE: The response `#status` and `#headers` must be configured before writing the response body (i.e. calling `#text` or `#json`).
  module Action
    include Callbacks

    # This method will be called wrapped by [callbacks](https://github.com/vladfaust/callbacks.cr).
    abstract def call

    # Optional params definition block. It's powered by [Params](https://github.com/vladfaust/params.cr) shard.
    #
    # However, to avoid original cumbersome NamedTuple syntax, a new simpler syntax is implemented:
    #
    # ```
    # params do
    #   type id : Int32
    #   type foo : Array(String) | Nil
    #   type user, nilable: true do
    #     type name : String
    #     type email : String?
    #   end
    # end
    #
    # # Is essentialy the same as
    #
    # Params.mapping({
    #   id:   Int32,
    #   foo:  Array(String) | Nil,
    #   user: {
    #     name:  String,
    #     email: String?,
    #   } | Nil,
    # })
    # ```
    #
    # Params can be accessed directly by their names (e.g. `id`) both in `#call` method and callbacks.
    macro params(&block)
      ::Params.mapping({
        {{run("./params/macro_parser", yield.id)}}
      })

      def self.new(context : HTTP::Server::Context)
        # It complicated because an including object can be a struct
        i = new(context.request, max_body_size, preserve_body)
        i.context = context
        i
      end
    end

    macro included
      # Initialize and invoke `#call` with [callbacks](https://github.com/vladfaust/callbacks.cr).
      def self.call(context : HTTP::Server::Context)
        new(context).call_with_callbacks
      end

      # Will **not** raise on exceed when reading from body in the `#call` method, however could raise on params parsing.
      class_getter max_body_size : UInt64 = UInt64.new(8 * 1024 ** 2)
      protected class_setter max_body_size

      # Change to `true` to preserve body upon params parsing.
      # Has effect only in cases when params are read from body.
      class_getter preserve_body : Bool = false
      protected class_setter preserve_body
    end

    # :nodoc:
    def call_with_callbacks
      with_callbacks { call }
    rescue Halt
    end

    @body : String?

    # Lazy string version of request body (read `.max_body_size` bytes on the first call).
    #
    # ```
    # # Action A
    # def call
    #   body                 # => "foo"
    #   context.request.body # => nil
    # end
    #
    # # Action B
    # def call
    #   context.request.body # => "foo"
    #   body                 # => likely to be nil, because already read above
    # end
    # ```
    def body
      @body ||= context.request.body.try &.gets(limit: self.class.max_body_size)
    end

    # Current HTTP::Server context.
    getter! context : HTTP::Server::Context
    protected setter context

    def initialize(@context : HTTP::Server::Context)
    end

    # Set HTTP *status*, close the response and **stop** the execution.
    # Optionally specify *response*, otherwise print a default HTTP response for this *status*.
    #
    # ```
    # def call
    #   halt(403)  # Will print "Unauthorized" into the response body
    #   text("ok") # This line will not be called
    # end
    #
    # def call
    #   halt(500, "Something's wrong!") # Will print "Something's wrong!" into the response body
    # end
    #
    # def call
    #   halt(409, {error: "Oops"}) # Will print "Oops" and set content type to JSON
    # end
    #
    # def call
    #   halt(403, PaymentError) # Will call #to_json on PaymentError
    # end
    # ```
    macro halt(status, response = nil)
      status({{status.id}})

      {% if response.is_a?(StringLiteral) || response.is_a?(StringInterpolation) %}
        text({{response}})
      {% elsif response.is_a?(NilLiteral) %}
        text(HTTP.default_status_message_for({{status.id}}))
      {% else %}
        json({{response}})
      {% end %}

      raise Halt.new
    end

    # Set HTTP status code.
    #
    # ```
    # def call
    #   status(400)
    # end
    # ```
    def status(new_status value)
      context.response.status_code = value
    end

    # Set HTTP header.
    #
    # ```
    # def call
    #   header("Content-Type", "application/json")
    # end
    # ```
    def header(name, value)
      context.response.headers[name] = value
    end

    # Set response status code to *code* and "Location" header to *location*.
    #
    # Does **not** interrupt the call.
    #
    # ```
    # def call
    #   redirect("https://google.com")
    #   puts "will be called"
    # end
    # ```
    def redirect(location : String | URI, code = 302)
      status(code)
      header("Location", location.to_s)
    end

    private CONTENT_TYPE_TEXT = "text/html; charset=utf-8"

    {% begin %}
      # Write text into the response body.
      # "Content-Type" header is set to `"{{CONTENT_TYPE_TEXT}}"`.
      #
      # ```
      # def call
      #   text("ok")
      # end
      # ```
      def text(value)
        header("Content-Type", CONTENT_TYPE_TEXT)
        context.response.print(value)
      end

      # Set the status to *status* and write text *value* into the response body.
      # "Content-Type" header is set to `"{{CONTENT_TYPE_TEXT}}"`.
      #
      # ```
      # def call
      #   text(200, "ok")
      # end
      # ```
      def text(status : Int, value)
        status(status)
        text(value)
      end
    {% end %}

    private CONTENT_TYPE_JSON = "application/json; charset=utf-8"

    {% begin %}
      # Cast *value* to JSON and write it into the response body.
      # "Content-Type" header is set to `"{{CONTENT_TYPE_JSON}}"`.
      #
      # ```
      # def call
      #   json(object)
      # end
      # ```
      def json(value)
        header("Content-Type", CONTENT_TYPE_JSON)
        value.to_json(context.response)
        context.response.close
      end

      # Set the status to *status*, cast *value* to JSON and write it into the response body.
      # "Content-Type" header is set to `"{{CONTENT_TYPE_JSON}}"`.
      #
      # ```
      # def call
      #   json(201, {
      #     object: object
      #   })
      # end
      # ```
      def json(status : Int, value)
        status(status)
        json(value)
      end
    {% end %}

    private class Halt < Exception
    end
  end
end
