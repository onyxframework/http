require "colorize"
require "logger"

require "../rescuer"
require "../../ext/http/request/id"

module Onyx::HTTP::Middleware
  module Rescuer
    # A rescuer which logs a error colorfully into a standard `::Logger`.
    # It also logs the `::HTTP::Request#id` if it's present.
    # Should be put *after* `Logger` in the stack.
    #
    # ```
    # logger = Onyx::HTTP::Middleware::Logger.new
    # renderer = Onyx::HTTP::Middleware::Renderer.new
    # rescuer = Onyx::HTTP::Middleware::Rescuers::Standard(Exception).new(renderer)
    # router = Onyx::HTTP::Middleware::Router.new
    # handlers = [logger, rescuer, router, renderer]
    # ```
    class Standard(T)
      include Rescuer(T)

      # A `Logger` to log to. Can be changed in runtime.
      property logger : ::Logger

      # Set *verbose* to `false` to turn off logging errors' backtraces.
      def initialize(
        next_handler : ::HTTP::Handler? = nil,
        @logger : ::Logger = ::Logger.new(STDERR),
        @verbose : Bool = true
      )
        super(next_handler)
      end

      # Log the *error* into the `#logger`.
      def handle(context, error)
        io = IO::Memory.new

        if id = context.request.id
          io << "[#{id[0...8]}] ".colorize(:dark_gray)
        end

        io << " ERROR ".rjust(7).colorize.mode(:bold).back(:red)
        io << " " << (error.message || "<Empty message error>")

        if @verbose
          io << "\n\n" << error.inspect_with_backtrace.colorize(:light_gray)
        end

        @logger.error(io.to_s)
      end
    end
  end
end
