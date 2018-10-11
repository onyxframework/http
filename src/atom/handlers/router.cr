require "radix"
require "http/server/handler"
require "http/web_socket"

require "../ext/http/request/path_params"
require "../ext/http/server/context/proc"

module Atom::Handlers
  # Routes a request's path, assigning matching proc to `HTTP::Server::Context#proc` and path params to `HTTP::Request#path_params`.
  #
  # When the route is found, calls the next handler if present.
  # So you should put a processing handler thereafter (or implement server logic).
  #
  # ```
  # router = Atom::Handlers::Router.new do
  #   get "/" do |context|
  #     context.response.print("Hello world!")
  #   end
  #
  #   ws "/" do |socket, context|
  #     socket.on_message do |message|
  #       # ...
  #     end
  #   end
  # end
  #
  # server = HTTP::Server.new(5000, [router]) do |context|
  #   if proc = context.proc
  #     proc.call(context)
  #   else
  #     context.response.respond_with_error("Not Found", 404)
  #   end
  # end
  # ```
  #
  # This handler can be extended with `Action` and `Channel` shortcuts.
  # See corresponding module docs for mor information.
  class Router
    include HTTP::Handler

    alias ContextProc = ::Proc(HTTP::Server::Context, Nil)
    alias WebSocketProc = ::Proc(HTTP::WebSocket, HTTP::Server::Context, Nil)
    private alias Node = ContextProc | HTTP::WebSocketHandler

    # :nodoc:
    HTTP_METHODS = %w(get post put patch delete options)
    @tree = Radix::Tree(Node).new
    @hash = {} of String => Node

    # Initialize a new router and yield it. You should then define routes in *&block*.
    #
    # ```
    # # The simplest router
    # router = Handlers::Router.new do
    #   get "/" do |env|
    #     env.response.print "Hello world!"
    #   end
    # end
    # ```
    def self.new
      instance = new
      with instance yield
      instance
    end

    # Lookup for a route and invoke `call_next` if succeeded. Raises `NotFoundError` otherwise.
    def call(context)
      if context.request.headers.includes_word?("Upgrade", "Websocket")
        path = "/ws" + context.request.path
        result = lookup(path)
      else
        path = "/" + context.request.method.downcase + context.request.path
        result = lookup(path)
      end

      context.proc = result.payload
      context.request.path_params = result.params

      call_next(context) if @next
    end

    # Draw a route for *path* and *methods*.
    #
    # ```
    # router = Handlers::Router.new do
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

    # Draw a empty (status 200) route for *path* and *methods*.
    #
    # ```
    # router = Handlers::Router.new do
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
      # router = Handlers::Router.new do
      #   {{method.id}} "/bar" do |context|
      #     context.response.print("Hello from {{method.upcase.id}} /bar!")
      #   end
      # end
      # ```
      def {{method.id}}(path, &proc : ContextProc)
        on(path, [{{method}}], &proc)
      end

      # Draw a empty (status 200) route for *path* with `{{method.upcase.id}}` method.
      #
      # ```
      # router = Handlers::Router.new do
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
    # router = Handlers::Router.new do
    #   ws "/foo/:bar" do |socket, context|
    #     socket.send("Hello WS!")
    #   end
    # end
    # ```
    def ws(path, &proc : WebSocketProc)
      add("/ws" + path, HTTP::WebSocketHandler.new(&proc))
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
