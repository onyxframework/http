require "colorize"
require "../rescuer"
require "../ext/http/server/response/error"

class Onyx::REST
  # HTTP handlers which rescue errors.
  module Rescuers
    # A handler which rescues all `Exception`s and logs them colorfully into a standard `Logger`.
    # It sets `HTTP::Context::Response#error` to the error instance before handler call,
    # otherwise it prints the `"500 Internal Server Error"` message into the response body.
    # It also logs the `HTTP::Request#id` if it's present.
    class Standard < Rescuer(Exception)
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

      def before_handler(context : HTTP::Server::Context, error : Exception)
        context.response.error = error
      end

      def fallback(context : HTTP::Server::Context, error : Exception)
        context.response.respond_with_error
      end
    end
  end
end
