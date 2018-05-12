require "radix"
require "http/web_socket"
require "./ext/http/request/action"
require "./ext/http/request/path_params"
require "./router/*"
require "./action"
require "./channel"

module Prism
  # Routes a request's path, injecting matching `ContextProc` into `context.request.action` and path params into `context.request.path_params`.
  #
  # Always calls next handler.
  #
  # See `Cacher` for known caching implementations.
  #
  # ```
  # router = Prism::Router.new do
  #   get "/" do |context|
  #     context.response.print("Hello world!")
  #   end
  # end
  #
  # server = HTTP::Server.new(5000, [router]) do |context|
  #   action.call(context) if action = context.request.action
  # end
  # ```
  class Router
    include HTTP::Handler

    private alias ContextProc = ::Proc(HTTP::Server::Context, Nil)
    private alias WebSocketProc = ::Proc(HTTP::WebSocket, HTTP::Server::Context, Nil)
    private alias Node = ContextProc | HTTP::WebSocketHandler

    # :nodoc:
    HTTP_METHODS = %w(get post put patch delete options)
    @tree = Radix::Tree(Node).new

    # Cacher used by this router. Can be changed in the runtime.
    property cacher

    # Initialize a new router with optional *cacher* and yield it. You should then define routes in *&block*.
    #
    # ```
    # # The simplest router
    # router = Prism::Router.new do
    #   get "/" do |env|
    #     env.response.print "Hello world!"
    #   end
    # end
    #
    # # Add some caching
    # cacher = Prism::Router::SimpleCacher.new(10_000)
    # router = Prism::Router.new(cacher) do
    #   # ditto
    # end
    # ```
    def initialize(@cacher : Cacher? = nil)
    end

    def self.new(cacher = nil)
      instance = Router.new(cacher)
      with instance yield
      instance
    end

    def call(context : HTTP::Server::Context)
      if context.request.headers.includes_word?("Upgrade", "Websocket")
        path = "/ws" + context.request.path
        result = @cacher ? @cacher.not_nil!.find(@tree, path) : @tree.find(path)
      else
        path = "/" + context.request.method.downcase + context.request.path
        result = @cacher ? @cacher.not_nil!.find(@tree, path) : @tree.find(path)
      end

      if result.found?
        context.request.action = result.payload
        context.request.path_params = result.params
      end

      call_next(context)
    end

    # Draw a route for *path* and *methods*.
    #
    # ```
    # router = Prism::Router.new do
    #   on "/foo", methods: %w(get post) do |context|
    #     context.response.print("Hello from #{context.request.method} /foo!")
    #   end
    # end
    # ```
    def on(path, methods : Array(String), &proc : ContextProc)
      methods.map(&.downcase).each do |method|
        begin
          @tree.add("/" + method + path, proc)
        rescue Radix::Tree::DuplicateError
          raise DuplicateRouteError.new(method.upcase + " " + path)
        end
      end
    end

    # Draw a route for *path* and *methods* calling *action*.
    #
    # ```
    # router = Prism::Router.new do
    #   on "/foo", methods: %w(get post), MyAction
    # end
    # ```
    def on(path, methods : Array(String), action : Action.class)
      methods.map(&.downcase).each do |method|
        begin
          @tree.add("/" + method + path, ContextProc.new { |c| action.call(c) }.as(Node))
        rescue Radix::Tree::DuplicateError
          raise DuplicateRouteError.new(method.upcase + " " + path)
        end
      end
    end

    # Draw a empty (status 200) route for *path* and *methods*.
    #
    # ```
    # router = Prism::Router.new do
    #   on "/foo", methods: %w(get post)
    # end
    # ```
    def on(path, methods : Array(String))
      methods.map(&.downcase).each do |method|
        begin
          @tree.add("/" + method + path, ContextProc.new { })
        rescue Radix::Tree::DuplicateError
          raise DuplicateRouteError.new(method.upcase + " " + path)
        end
      end
    end

    {% for method in HTTP_METHODS %}
      # Draw a route for *path* with `{{method.upcase.id}}` method.
      #
      # ```
      # router = Prism::Router.new do
      #   {{method.id}} "/bar" do |context|
      #     context.response.print("Hello from {{method.upcase.id}} /bar!")
      #   end
      # end
      # ```
      def {{method.id}}(path, &proc : ContextProc)
        on(path, [{{method}}], &proc)
      end

      # Draw a route for *path* with `{{method.upcase.id}}` calling *action*.
      #
      # ```
      # router = Prism::Router.new do
      #   {{method.id}} "/bar", MyAction
      # end
      # ```
      def {{method.id}}(path, action : Action.class)
        on(path, [{{method}}], action)
      end

      # Draw a empty (status 200) route for *path* with `{{method.upcase.id}}` method.
      #
      # ```
      # router = Prism::Router.new do
      #   {{method.id}} "/bar"
      # end
      # ```
      def {{method.id}}(path)
        on(path, [{{method}}])
      end
    {% end %}

    # Draw a WebSocket route for *path*.
    #
    # A request is currently determined as websocket by `"Upgrade": "Websocket"` header.
    #
    # ```
    # router = Prism::Router.new do
    #   ws "/foo/:bar" do |socket, context|
    #     socket.send("Hello WS!")
    #   end
    # end
    # ```
    def ws(path, &proc : WebSocketProc)
      begin
        @tree.add("/ws" + path, HTTP::WebSocketHandler.new(&proc))
      rescue Radix::Tree::DuplicateError
        raise DuplicateRouteError.new("WS " + path)
      end
    end

    # Draw a WebSocket route for *path* instantiating *channel*.
    #
    # A request is currently determined as websocket by `"Upgrade": "Websocket"` header.
    #
    # ```
    # router = Prism::Router.new do
    #   ws "/foo/:bar", MyChannel
    # end
    # ```
    def ws(path, channel : Channel.class)
      begin
        @tree.add("/ws" + path, WebSocketProc.new { |s, c| MyChannel.call(s, c) }.as(Node))
      rescue Radix::Tree::DuplicateError
        raise DuplicateRouteError.new("WS " + path)
      end
    end

    # Raised if duplicate route found.
    class DuplicateRouteError < Exception
      getter route : String

      def initialize(@route)
        super("Duplicate route found: #{route}")
      end
    end
  end
end
