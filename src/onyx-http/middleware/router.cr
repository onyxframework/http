require "radix"

require "http/server/handler"
require "http/web_socket"

require "../ext/http/request/path_params"
require "./router/*"

module Onyx::HTTP::Middleware
  # Routes a request's path, then updates extracted path params to
  # `::HTTP::Request#path_params`, executes the matching proc and calls the next handler
  # if it's present.
  #
  # Raises `Router::NotFound` if no route is found for the URL path,
  # `Router::MethodNotAllowed` if the request method is not allowed or
  # `Router::UpgradeRequired` if the endpoint requires websocket protocol.
  #
  # ```
  # router = Onyx::HTTP::Middleware::Router.new do |r|
  #   r.get "/" do |env|
  #     env.response << "Hello world!"
  #   end
  #
  #   r.ws "/" do |socket, env|
  #     socket.on_message do |message|
  #       # ...
  #     end
  #   end
  #
  #   r.on "/users" do
  #     r.post "/", Endpoint::User::Create
  #     r.get "/:id", Endpoint::User::Get
  #   end
  # end
  #
  # renderer = Onyx::HTTP::Middleware::Renderer.new
  # rescuer = Onyx::HTTP::Middleware::Rescuer::Standard(Exception).new(renderer)
  # server = Onyx::HTTP::Server.new([rescuer, router, renderer])
  # ```
  class Router
    include ::HTTP::Handler

    private alias ContextProc = Proc(::HTTP::Server::Context, Nil)
    private alias Node = ContextProc | WebSocketHandler

    # :nodoc:
    HTTP_METHODS = %w(get head post put patch delete options)
    @tree = Radix::Tree(Node).new
    @hash = {} of String => Node

    getter namespace = Array(String).new

    # Initialize a new router and yield it. You should then define routes in the *&block*.
    #
    # ```
    # # The simplest router
    # router = Router.new do |r|
    #   r.get "/" do |env|
    #     env.response << "Hello world!"
    #   end
    # end
    # ```
    def self.new
      instance = new
      yield instance
      instance
    end

    # Lookup for a route, update `context.request.path_params` and call the matching proc,
    # raising `RouteNotFound` otherwise. Calls the next handler if it's present.
    def call(context)
      if context.request.headers.includes_word?("Upgrade", "Websocket")
        path = "/ws" + context.request.path.rstrip('/')
        result = lookup(path)
      else
        path = '/' + context.request.method.downcase + context.request.path.rstrip('/')
        result = lookup(path)
      end

      if proc = result.payload
        if params = result.params
          context.request.path_params = params
        end

        proc.call(context)

        if self.next
          call_next(context)
        end
      else
        found = Array(String).new

        HTTP_METHODS.each do |method|
          next if method == context.request.method.downcase
          path = '/' + method + context.request.path.rstrip('/')
          found << method if lookup(path).payload
        end

        unless found.empty?
          context.response.headers["Allow"] = found.map(&.upcase).join(", ")
          raise MethodNotAllowed.new
        end

        unless context.request.headers.includes_word?("Upgrade", "Websocket")
          path = "/ws" + context.request.path.rstrip('/')

          if lookup(path).payload
            context.response.headers["Upgrade"] = "Websocket"
            raise UpgradeRequired.new
          end
        end

        raise NotFound.new
      end
    end

    # Yield `self` with a *namespace*.
    # The *namespace* can also be empty or `nil`, so you can prettify your router blocks.
    #
    # ```
    # router = Router.new do |r|
    #   r.on "/users" do
    #     r.post "/"   # Resulting route is "POST /users/"
    #     r.get "/:id" # Resulting route is "GET /users/:id"
    #   end
    # end
    # ```
    def on(namespace : String? = nil, &block : self ->)
      if namespace && !namespace.empty?
        @namespace.push(namespace)
        yield self
        @namespace.pop
      else
        yield self
      end
    end

    # Draw a route for *path* and *methods*. If a `View` instance is returned,
    # then the `::HTTP::Server::Response#view` is set to this view.
    #
    # ```
    # router = Router.new do |r|
    #   r.on "/foo", methods: %w(get post) do |env|
    #     env.response << "Hello from #{env.request.method} /foo!"
    #   end
    # end
    # ```
    def on(path, methods : Array(String), &proc : ::HTTP::Server::Context -> View | _)
      methods.map(&.downcase).each do |method|
        add('/' + method, path, ContextProc.new do |context|
          view? = proc.call(context)

          if view = view?.as?(HTTP::View)
            context.response.view ||= view
          end
        end)
      end
    end

    # Draw a route for *path* and *methods* calling *endpoint*. See `Endpoint`.
    # If a `View` instance is returned, then the `::HTTP::Server::Response#view` is set
    # to this view.
    #
    # ```
    # router = Router.new do |r|
    #   r.on "/foo", methods: %w(get post), MyEndpoint
    # end
    # ```
    def on(path, methods : Array(String), endpoint : HTTP::Endpoint.class)
      on(path, methods) do |context|
        endpoint.call(context)
      end
    end

    {% for method in HTTP_METHODS %}
      # Draw a route for *path* with `{{method.upcase.id}}` method. If a `View` instance
      # is returned, then the `::HTTP::Server::Response#view` is set to this view.
      #
      # ```
      # router = Router.new do |r|
      #   r.{{method.id}} "/bar" do |env|
      #     env.response << "Hello from {{method.upcase.id}} /bar!"
      #   end
      # end
      # ```
      def {{method.id}}(path, &proc : ::HTTP::Server::Context -> View | _)
        on(path, [{{method}}], &proc)
      end

      # Draw a route for *path* with `{{method.upcase.id}}` calling *endpoint*.
      # See `Endpoint`. If a `View` instance is returned, then the
      # `::HTTP::Server::Response#view` is set  to this view.
      #
      # ```
      # router = Router.new do |r|
      #   r.{{method.id}} "/bar", MyEndpoint
      # end
      # ```
      def {{method.id}}(path, endpoint : HTTP::Endpoint.class)
        on(path, [{{method}}], endpoint)
      end
    {% end %}

    # Draw a `"ws://"` route for *path*.
    #
    # A request is currently determined as websocket by `"Upgrade": "Websocket"` header.
    #
    # ```
    # router = Router.new do |r|
    #   r.ws "/foo/:bar" do |socket, env|
    #     socket.send("Hello WS!")
    #   end
    # end
    # ```
    def ws(path, &proc : ::HTTP::WebSocket, ::HTTP::Server::Context ->)
      add("/ws", path, WebSocketHandler.new(&proc))
    end

    # Draw a `"ws://"` route for *path* binding *channel*. See `Channel`.
    # A request is currently determined as websocket by `"Upgrade": "Websocket"` header.
    #
    # ```
    # router = Router.new do |r|
    #   r.ws "/foo", MyChannel
    # end
    # ```
    def ws(path, channel : T.class) : Nil forall T
      {%
        a = 42 # Crystal formatter bug

        unless T < Onyx::HTTP::Channel
          raise <<-TEXT
          \e[41m Onyx::HTTP compilation error \e[0m — \e[33m\e[1mMiddleware::Router#ws\e[0m must be called with class including \e[32m\e[1mChannel\e[0m, given \e[31m\e[1m#{T}\e[0m
          TEXT
        end
      %}

      ch = uninitialized T

      ws_handler = WebSocketHandler.new do |socket, context|
        ch.bind(socket)
      end

      add("/ws", path, ContextProc.new do |context|
        ch = channel.new(context)
        ws_handler.call(context)
      end)
    end

    # Raised if a duplicate route is found.
    class DuplicateRouteError < Exception
      # The route which caused the error.
      getter route : String

      # :nodoc:
      def initialize(@route)
        super("Duplicate route found: #{route}")
      end
    end

    protected def add(method, path, node)
      if @namespace.empty?
        resulting_path = method + path.rstrip('/')
      else
        resulting_path = method + @namespace.join + path.rstrip('/')
      end

      if resulting_path.includes?(':')
        @tree.add(resulting_path, node)
      else
        raise DuplicateRouteError.new(resulting_path) if @hash.has_key?(resulting_path)
        @hash[resulting_path] = node
      end
    rescue Radix::Tree::DuplicateError
      raise DuplicateRouteError.new(path)
    end

    private struct Result
      getter payload : Node?
      getter params : Hash(String, String)? = nil

      def initialize(@payload : Node?)
      end

      def initialize(result : Radix::Result)
        if result.found?
          @payload = result.payload
          @params = result.params
        end
      end
    end

    protected def lookup(path)
      Result.new(@hash.fetch(path) do
        @tree.find(path)
      end)
    end
  end
end
