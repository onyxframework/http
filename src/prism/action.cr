require "http/server"
require "json"
require "./callbacks"

module Prism
  # A callable HTTP action with `Callbacks` included.
  #
  # NOTE: *(From [API](https://crystal-lang.org/api/0.23.1/HTTP/Server/Response.html)) The response #status_code and #headers must be configured before writing the response body. Once response output is written, changing the status and #headers properties has no effect.*
  #
  # ```
  # struct MyAction < Prism::Action
  #   def call
  #     text("ok")
  #   end
  #
  #   after do
  #     p "MyAction: ok"
  #   end
  # end
  #
  # MyAction.call(env)
  # # => "ok"
  # ```
  abstract struct Action
    macro inherited
      include Prism::Callbacks
    end

    abstract def call

    # Initialize and invoke `#call` with `#before`, `#around` and `#after` callbacks.
    def self.call(context : ::HTTP::Server::Context)
      new(context).call_with_callbacks
    end

    # :nodoc:
    def call_with_callbacks
      with_callbacks { call }
    end

    # Will **not** raise on exceed, defaults to 8 MB.
    class_property max_body_size = UInt64.new(8 * 1024 ** 2)

    @body : String?

    # Lazy string version of request body (read *max_body_size* bytes on the first call).
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
    #   context.request.body # => Not nil
    # end
    # ```
    def body
      @body ||= context.request.body.try &.gets(limit: self.class.max_body_size)
    end

    # Current context.
    getter context : ::HTTP::Server::Context

    # :nodoc:
    def initialize(@context : ::HTTP::Server::Context)
    end

    # Set HTTP *status*, close the response and **stop** the execution.
    # Optionally specify *message*, otherwise print a default HTTP message for this *status*.
    #
    # ```
    # def call
    #   halt!(500, "Something's wrong!")
    #   text("ok") # => This line will not be called
    # end
    # ```
    macro halt!(status, message = nil)
      status({{status.id}})
      text({{message}} || HTTP.default_status_message_for({{status.id}}))
      return false
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
        context.response.content_type = CONTENT_TYPE_TEXT
        context.response.print(value)
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
        context.response.content_type = CONTENT_TYPE_JSON
        context.response.print(value.to_json)
      end
    {% end %}
  end
end

require "./action/*"
