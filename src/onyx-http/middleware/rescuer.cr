require "http/server/handler"
require "../ext/http/server/response/error"

# Rescues `T`. Firstly calls `#handle` to handle the error (e.g. log it).
# Calls `#before_next_handler` and then the `#next_handler`.
#
# See `Rescuer::Standard` and `Rescuer::Silent`.
module Onyx::HTTP::Middleware::Rescuer(T)
  include ::HTTP::Handler

  # A handler to call when a error is rescued.
  property next_handler : ::HTTP::Handler

  # Initialize with a *next_handler* to call when a error is rescued.
  def initialize(@next_handler : ::HTTP::Handler)
  end

  # :nodoc:
  def call(context)
    call_next(context)
  rescue error : T
    handle(context, error)
    before_next_handler(context, error)
    next_handler.call(context)
  end

  # Process the error before further handling. A good example is logging it.
  abstract def handle(context : ::HTTP::Server::Context, error : T)

  # Called just before the `#next_handler` is called.
  # It does `context.response.error = error` by default.
  def before_next_handler(context : ::HTTP::Server::Context, error : T)
    context.response.error = error
  end
end

require "./rescuer/*"
