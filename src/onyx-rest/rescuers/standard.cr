require "colorize"
require "../rescuer"
require "../ext/http/server/response/error"

class Onyx::REST
  # HTTP handlers which rescue errors.
  module Rescuers
    # A handler which rescues all `Exception`s and logs them colorfully into a standard `Logger`.
    # It sets `HTTP::Server::Response#error` to the error instance before *handler* call,
    # otherwise prints the `"500 Internal Server Error"` message into the response body.
    # It also logs the `HTTP::Request#id` if it's present.
    # Should be put after logger in the stack.
    #
    # ```
    # # Will print "500 Internal Server Error" into the response
    # rescuer = Onyx::REST::Rescuers::Standard.new
    # handlers << logger
    # handlers << rescuer
    # handlers << router
    # ```
    #
    # ```
    # renderer = Onyx::REST::Renderers::JSON.new
    #
    # # Will update `context.response.error` and call the renderer
    # rescuer = Onyx::REST::Rescuers::Standard.new(renderer)
    #
    # handlers << logger
    # handlers << rescuer
    # handlers << router
    # handlers << renderer
    # ```
    #
    # FIXME: Make generic. See [https://github.com/crystal-lang/crystal/issues/7200](https://github.com/crystal-lang/crystal/issues/7200).
    class Standard < Rescuer(Exception)
      # A `Logger` to log to. Can be changed in runtime.
      property logger : Logger

      # Set *verbose* to `false` to turn off logging errors' backtraces.
      def initialize(
        handler : HTTP::Handler? = nil,
        *,
        @logger : Logger = Logger.new(STDERR),
        @verbose : Bool = true
      )
        super(handler)
      end

      # Log the *error* into the `#logger`.
      def process(context : HTTP::Server::Context, error : Exception)
        io = IO::Memory.new

        if id = context.request.id?
          io << "[#{id[0...8]}] ".colorize(:dark_gray)
        end

        io << " ERROR ".rjust(7).colorize.mode(:bold).back(:red)

        io << " " << (error.message || "<Empty message error>")

        if @verbose
          io << "\n\n" << error.inspect_with_backtrace.colorize(:light_gray)
        end

        @logger.error(io.to_s)
      end

      # Update `HTTP::Server::Response#error` with *error*.
      def before_handler(context : HTTP::Server::Context, error : Exception)
        context.response.error = error
      end

      # Print `"500 Internal Server Error"` into the response body.
      def fallback(context : HTTP::Server::Context, error : Exception)
        context.response.respond_with_error
      end
    end
  end
end
