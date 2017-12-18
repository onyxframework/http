require "http/server"
require "json"
require "./callbacks"

module Rest
  # A callable HTTP action with `Callbacks` included.
  #
  # NOTE: *(From [API](https://crystal-lang.org/api/0.23.1/HTTP/Server/Response.html)) The response #status_code and #headers must be configured before writing the response body. Once response output is written, changing the status and #headers properties has no effect.*
  #
  # ```
  # struct MyAction < Rest::Action
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
      include Rest::Callbacks

      before do
        copy_body; true # TODO: Ability to prevent copying
      end
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

    # Body `String` version. The request `IO` body is still available.
    getter body : String?

    # Copies the request body into `#body`, preserving the original `IO` as is.
    # By default is invoked in `#before` callback.
    def copy_body
      if @context.request.body
        io = IO::Memory.new
        IO.copy(@context.request.body.not_nil!, io)
        io.rewind
        @body = io.gets_to_end
        io.rewind
        @context.request.body = io
        @body
      end
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
