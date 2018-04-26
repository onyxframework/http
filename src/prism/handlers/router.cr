require "radix"
require "http/web_socket"
require "../ext/http/request/action"
require "../ext/http/request/path_params"

# Routes a request's path, injecting matching `ContextProc` into `context.request.action` and path params into `context.request.path_params`.
#
# Always calls next handler.
#
# Has a built-in Hash cache with default capacity equals to `CACHE_CAPACITY`.Thanks [@samueleaton](https://github.com/samueleaton) for the idea.
#
# ```
# require "prism/handlers/router"
#
# router = Prism::Handlers::Router.new do
#   get "/" do |context|
#     context.response.print("Hello world!")
#   end
# end
#
# server = HTTP::Server.new(5000, [router]) do |context|
#   action.call(context) if action = context.request.action
# end
# ```
class Prism::Handlers::Router
  include HTTP::Handler
  alias ContextProc = ::Proc(HTTP::Server::Context, Nil)
  alias WebSocketProc = ::Proc(HTTP::WebSocket, HTTP::Server::Context, Nil)
  alias Node = ContextProc | HTTP::WebSocketHandler

  # Default cache capacity. The cache is being cleared afterwards.
  CACHE_CAPACITY = 10_000

  # :nodoc:
  HTTP_METHODS = %w(get post put patch delete options)
  @tree = Radix::Tree(Node).new
  @cached_tree = {} of String => Radix::Result(Node)

  # Initialize a new router with *cache_capacity* default to 10k and yield it. You should then define routes in *&block*.
  #
  # ```
  # # The simplest router
  # router = Prism::Handlers::Router.new do |r|
  #   r.get "/" do |env|
  #     env.response.print "Hello world!"
  #   end
  # end
  # ```
  def initialize(@cache_capacity = CACHE_CAPACITY, &block)
    yield self
  end

  def call(context : HTTP::Server::Context)
    if context.request.headers.includes_word?("Upgrade", "Websocket")
      result = wrapped_search("/ws" + context.request.path)
    else
      result = wrapped_search("/" + context.request.method.downcase + context.request.path)
    end

    if result.found?
      context.request.action = result.payload
      context.request.path_params = result.params
    end

    call_next(context)
  end

  private def wrapped_search(path)
    if cached_result = @cached_tree[path]?
      return cached_result
    else
      result = @tree.find(path)

      if result.found?
        @cached_tree.clear if @cached_tree.size > @cache_capacity
        @cached_tree[path] = result
      end

      return result
    end
  end

  # Draw a route for *path* and *methods*.
  #
  # ```
  # router = Prism::Handlers::Router.new do |r|
  #   r.on "/foo", methods: %w(get post) do |context|
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

  {% for method in HTTP_METHODS %}
    # Draw a route for *path* with `{{method.upcase.id}}` method.
    #
    # ```
    # router = Prism::Handlers::Router.new do
    #   {{method.id}} "/bar" do |context|
    #     context.response.print("Hello from {{method.upcase.id}} /bar!")
    #   end
    # end
    # ```
    def {{method.id}}(path, &proc : ContextProc)
      on(path, [{{method}}], &proc)
    end
  {% end %}

  # Draw a WebSocket route for *path*.
  #
  # A request is currently determined as websocket by `"Upgrade": "Websocket"` header.
  #
  # ```
  # router = Prism::Handlers::Router.new do |r|
  #   r.ws "/foo/:bar" do |socket, context|
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

  # Raised if duplicate route found
  class DuplicateRouteError < Exception
    getter route : String

    def initialize(@route)
      super("Duplicate route found: #{route}")
    end
  end
end
