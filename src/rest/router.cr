require "radix"
require "./ext/http/request/action"
require "./ext/http/request/path_params"

module Rest
  # Routes a request's path, injecting matching `ContextProc` into `context.request.action` and path params into `context.request.path_params`.
  #
  # Always calls next handler.
  #
  # ```
  # require "rest/router"
  #
  # router = Rest::Router.new do
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
    alias ContextProc = ::Proc(HTTP::Server::Context, Nil)

    # :nodoc:
    HTTP_METHODS = %w(get post put patch delete options)
    @tree = Radix::Tree(ContextProc).new

    # Initialize a new router and yield it. You can define routes in *&block*.
    #
    # ```
    # # The simplest router
    # router = Rest::Router.new do |r|
    #   r.get "/" do |env|
    #     env.response.print "Hello world!"
    #   end
    # end
    # ```
    def initialize(&block)
      yield self
    end

    def call(context : HTTP::Server::Context)
      result = @tree.find("/" + context.request.method.downcase + context.request.path)

      if result.found?
        context.request.action = result.payload
        context.request.path_params = result.params
      end

      call_next(context)
    end

    {% for method in HTTP_METHODS %}
      # Draw a route for *path* with `{{method.upcase.id}}` method.
      #
      # ```
      # router = Rest::Router.new do
      #   {{method.id}} "/bar" do |context|
      #     context.response.print("Hello from {{method.upcase.id}} /bar!")
      #   end
      # end
      # ```
      def {{method.id}}(path, &proc : ContextProc)
        begin
          @tree.add("/" + {{method}} + path, proc)
        rescue Radix::Tree::DuplicateError
          raise DuplicateRouteError.new({{method.upcase}} + " " + path)
        end
      end
    {% end %}

    # Raised if duplicate route found
    class DuplicateRouteError < Exception
      getter route : String

      def initialize(@route)
        super("Duplicate route found: #{route}")
      end
    end
  end
end
