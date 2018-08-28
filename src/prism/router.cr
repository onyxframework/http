require "radix"
require "http/web_socket"
require "./ext/http/request/action"
require "./ext/http/request/path_params"
require "./action"
require "./channel"

module Prism
  # Routes a request's path, injecting matching `ContextProc` into `context.request.action` and path params into `context.request.path_params`.
  #
  # Always calls next handler.
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
    @hash = {} of String => Node

    # Initialize a new router and yield it. You should then define routes in *&block*.
    #
    # ```
    # # The simplest router
    # router = Prism::Router.new do
    #   get "/" do |env|
    #     env.response.print "Hello world!"
    #   end
    # end
    # ```
    def self.new
      instance = Router.new
      with instance yield
      instance
    end

    def call(context : HTTP::Server::Context)
      if context.request.headers.includes_word?("Upgrade", "Websocket")
        path = "/ws" + context.request.path
        result = lookup(path)
      else
        path = "/" + context.request.method.downcase + context.request.path
        result = lookup(path)
      end

      context.request.action = result.payload
      context.request.path_params = result.params

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
        add("/" + method + path, proc)
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
        add("/" + method + path, ContextProc.new { |c| action.call(c) }.as(Node))
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
        add("/" + method + path, ContextProc.new { })
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
      add("/ws" + path, HTTP::WebSocketHandler.new(&proc))
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
      add("/ws" + path, WebSocketProc.new { |s, c| MyChannel.call(s, c) }.as(Node))
    end

    # Raised if duplicate route found.
    class DuplicateRouteError < Exception
      getter route : String

      def initialize(@route)
        super("Duplicate route found: #{route}")
      end
    end

    protected def add(path, node)
      if path.includes?(':')
        @tree.add(path, node)
      else
        raise DuplicateRouteError.new(path) if @hash.has_key?(path)
        @hash[path] = node
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
