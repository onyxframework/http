require "radix"

require "http/server/handler"
require "http/web_socket"

require "./ext/http/server"
require "./ext/http/request/path_params"
require "./errors/not_found"

# Routes a request's path, assigning matching proc to `HTTP::Server::Context#proc`
# and path params to `HTTP::Request#path_params`. Calls the next handler in the stack
# regardless of the lookup result. If there is no next handler, processes the request itself,
# acting as a plain text renderer and properly rescuing `Onyx::REST::Error`s.
#
# If the method block (e.g. `get "/" { "this is the block" }`) returns `String`, then
# `HTTP::Server::Response#text` variable is set to that string an handled afterwards.
# In case of the router processing the proc itself, the `text` variable content
# is printed into the response body with trailing `"\n"`.
#
# To change how the request is processed, put a handler right after the router,
# e.g. `Onyx::Renderers::JSON`.
#
# ```
# router = Onyx::REST::Router.new do
#   # Response body: Hello World!\n
#   get "/" do
#     "Hello World!"
#   end
#
#   # Response body: Hello World!
#   get "/" do |env|
#     env.response.print("Hello world!")
#   end
#
#   ws "/" do |socket, env|
#     socket.on_message do |message|
#       # ...
#     end
#   end
# end
#
# server = Onyx::REST::Server.new([router])
# ```
class Onyx::REST::Router
  include HTTP::Handler

  private alias ContextProc = Proc(HTTP::Server::Context, Nil)
  private alias WebSocketProc = Proc(HTTP::WebSocket, HTTP::Server::Context, Nil)
  private alias Node = ContextProc | HTTP::WebSocketHandler

  # :nodoc:
  HTTP_METHODS = %w(get post put patch delete options)
  @tree = Radix::Tree(Node).new
  @hash = {} of String => Node

  # Initialize a new router and yield it. You should then define routes in the *&block*.
  #
  # ```
  # # The simplest router
  # router = Onyx::REST::Router.new do
  #   get "/" do
  #     "Hello world!"
  #   end
  # end
  # ```
  def self.new
    instance = new
    with instance yield
    instance
  end

  # Lookup for a route, set `context.proc` and `context.request.path_params` regardless
  # of the result and then call the next handler if it is present, otherwise process itself.
  def call(context)
    if context.request.headers.includes_word?("Upgrade", "Websocket")
      path = "/ws" + context.request.path.rstrip('/')
      result = lookup(path)
    else
      path = "/" + context.request.method.downcase + context.request.path.rstrip('/')
      result = lookup(path)
    end

    begin
      if proc = result.payload
        context.request.path_params = result.params

        proc.call(context)

        if self.next
          call_next(context)
        else
          if text = context.response.text
            context.response.content_type = "text/plain; charset=utf-8"
            context.response.output << text << "\n"
          end
        end
      else
        raise Onyx::REST::Errors::NotFound.new(context.request.method, context.request.path)
      end
    rescue ex : REST::Error
      if self.next
        context.response.error = ex
        call_next(context)
      else
        context.response.content_type = "text/plain; charset=utf-8"
        context.response.status_code = ex.code
        context.response.output << ex.code << " " << ex.message << "\n"
      end
    end
  end

  # Yield `with` self.
  #
  # ```
  # router.draw do
  #   post "/" { }
  #   get "/" { }
  # end
  # ```
  def draw(&block)
    with self yield
  end

  # Draw a route for *path* and *methods*.
  #
  # ```
  # router = Onyx::REST::Router.new do
  #   on "/foo", methods: %w(get post) do |env|
  #     "Hello from #{env.request.method} /foo!"
  #   end
  # end
  # ```
  def on(path, methods : Array(String), &proc : HTTP::Server::Context -> _)
    methods.map(&.downcase).each do |method|
      add("/" + method + path, proc)
    end
  end

  {% for method in HTTP_METHODS %}
    # Draw a route for *path* with `{{method.upcase.id}}` method.
    #
    # ```
    # router = Onyx::REST::Router.new do
    #   {{method.id}} "/bar" do
    #     "Hello from {{method.upcase.id}} /bar!"
    #   end
    # end
    # ```
    def {{method.id}}(path, &proc : HTTP::Server::Context -> _)
      on(path, [{{method}}], &proc)
    end
  {% end %}

  # Draw a WebSocket route for *path*.
  #
  # A request is currently determined as websocket by `"Upgrade": "Websocket"` header.
  #
  # ```
  # router = Onyx::REST::Router.new do
  #   ws "/foo/:bar" do |socket, env|
  #     socket.send("Hello WS!")
  #   end
  # end
  # ```
  def ws(path, &proc : HTTP::WebSocket, HTTP::Server::Context -> _)
    add("/ws" + path, HTTP::WebSocketHandler.new(&proc))
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

  protected def add(path, callable)
    if callable.is_a?(HTTP::WebSocketHandler)
      node = callable.as(HTTP::WebSocketHandler)
    else
      node = ->(context : HTTP::Server::Context) {
        result = callable.call(context)

        if result.is_a?(String)
          context.response.text = result
        end

        nil
      }.as(ContextProc)
    end

    if path.includes?(':')
      @tree.add(path.rstrip('/'), node)
    else
      raise DuplicateRouteError.new(path) if @hash.has_key?(path)
      @hash[path.rstrip('/')] = node
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
