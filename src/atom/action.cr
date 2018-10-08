require "http/server/context"
require "json"
require "callbacks"
require "params"

require "./handlers/router"

module Atom
  # A callable HTTP action with [Callbacks](https://github.com/vladfaust/callbacks.cr)
  # and [Params](https://github.com/vladfaust/params.cr) included.
  #
  # Params have special handy definition syntax, as seen in the example below:
  #
  # ```
  # struct MyAction
  #   include Atom::Action
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
  #     # Will explicitly write the text into the response body
  #     text("id = #{id}, foo = #{foo.join(", ")}, user name = #{user.not_nil!.name}")
  #
  #     # Or
  #     # Will *render* the object (see below)
  #     render({id: id, foo: foo, user: {name: user.name, email: user.email}})
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
  # By default `#render` prints the object as a text if it's a `String`, `Number` or `Bool`,
  # an writes a JSON otherwise. `#render` can be overriden to conform with an application's needs
  # (for example, by defining a custom `Renderer` module and including it into all actions), e.g:
  #
  # ```
  # # Will write a formatted JSON
  # module CustomRenderer
  #   def render(value)
  #     success = (200..299) === context.response.status_code
  #
  #     json = JSON::Builder.new(context.response.output)
  #     json.document do
  #       json.object do
  #         json.field("success", success)
  #         json.field(success ? "data" : "error") do
  #           value.to_json(json)
  #         end
  #         json.field("status", context.response.status_code)
  #       end
  #     end
  #
  #     context.response.content_type = "application/json; charset=utf-8"
  #   end
  # end
  # ```
  #
  # Router example:
  #
  # ```
  # router = Atom::Handlers::Router.new do
  #   get "/" do |context|
  #     MyAction.call(context)
  #   end
  #   # Or
  #   get "/", MyAction
  # end
  # ```
  #
  # NOTE: Params errors aren't rescued by default, you have to handle [`Params::Error`](http://github.vladfaust.com/params.cr/Params/Error.html) yourself.
  #
  # NOTE: The response `#status` and `#header` must be configured before writing the response body (i.e. calling `#render`, `#text` or `#json`).
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
        {{run("./ext/params/type_macro_parser", yield.id)}}
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

      # You can change `.max_body_size` per action basis.
      #
      # ```
      # struct MyAction
      #   include Atom::Action
      #   max_body_size = 1 * 1024 ** 3 # 1 GB
      # end
      # ```
      protected class_setter max_body_size

      # Change to `true` to preserve body upon params parsing.
      # Has effect only in cases when params are read from body.
      # Slightly decreases performance due to IO copying.
      class_getter preserve_body : Bool = false

      # You can change `.preserve_body` per action basis.
      #
      # ```
      # struct MyAction
      #   include Atom::Action
      #   preserve_body = true
      # end
      # ```
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

    @context : HTTP::Server::Context | Nil

    # Current HTTP::Server context.
    def context
      @context.not_nil!
    end

    protected setter context

    def initialize(@context : HTTP::Server::Context)
    end

    # :nodoc:
    class Halt < Exception
    end

    # **Halts** the execution skipping remaining callbacks, setting *status* and rendering *payload*.
    #
    # If no *payload* is passed, a default HTTP message (`String`) is used instead.
    # To avoid this, pass `nil` explicitly.
    #
    # ```
    # def call
    #   halt(403)  # Will call `#render(403, "Unauthorized")`
    #   text("ok") # This line will not be called
    # end
    #
    # def call
    #   halt(409, {error: "Oops"}) # Will call `#render(409, {error: "Oops"})`
    # end
    #
    # def call
    #   halt(500, nil) # Will call `#status(500)` only
    # end
    # ```
    macro halt(status, payload = HTTP.default_status_message_for(status))
      status = {{status}}
      %payload = {{payload}}

      if %payload
        render({{status}}, %payload)
      else
        status({{status}})
      end

      raise Halt.new
    end

    # Set HTTP status code.
    #
    # ```
    # def call
    #   status(400)
    # end
    # ```
    def status(new_status value : Int32)
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
    #   text("will be called")
    # end
    # ```
    def redirect(location : String | URI, code = 302)
      status(code)
      header("Location", location.to_s)
    end

    private CONTENT_TYPE_TEXT = "text/html; charset=utf-8"
    private CONTENT_TYPE_JSON = "application/json; charset=utf-8"

    # Render *value*. By default, calls `#text` on `String`, `Number`, `Bool`
    # and `#json` on other types.
    #
    # Remember that you can override it!
    def render(value)
      case value
      when String, Number, Bool
        text(value)
      else
        json(value)
      end
    end

    # Call `#status` and then `#render`.
    def render(status : Int, value)
      status(status)
      render(value)
    end

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

      # Call `#status` and then `#text`.
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

      # Cast *value* to JSON and write it into the response body.
      #
      # "Content-Type" header is set to `"{{CONTENT_TYPE_JSON}}"`.
      #
      # ```
      # def call
      #   json(object)
      # end
      # ```
      def json(value)
        context.response.content_type = CONTENT_TYPE_JSON
        json = JSON::Builder.new(context.response.output)
        json.document do
          value.to_json(json)
        end
      end

      # Call `#status` and then `#json`.
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
  end

  module Handlers
    class Router
      # Draw a route for *path* and *methods* calling *action*. See `Action`.
      #
      # ```
      # router = Atom::Handlers::Router.new do
      #   on "/foo", methods: %w(get post), MyAction
      # end
      # ```
      def on(path, methods : Array(String), action : Action.class)
        methods.map(&.downcase).each do |method|
          add("/" + method + path, ContextProc.new { |c| action.call(c) }.as(Node))
        end
      end

      {% for method in HTTP_METHODS %}
        # Draw a route for *path* with `{{method.upcase.id}}` calling *action*. See `Action`.
        #
        # ```
        # router = Atom::Handlers::Router.new do
        #   {{method.id}} "/bar", MyAction
        # end
        # ```
        def {{method.id}}(path, action : Action.class)
          on(path, [{{method}}], action)
        end
      {% end %}
    end
  end
end
