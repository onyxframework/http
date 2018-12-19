require "http/server/handler"

# Rescues `T`. Firstly calls `#process` to handle the error (e.g. log it).
# Then if `#handler` is present, calls `#before_handler` and then the handler itself.
# Otherwise calls `#fallback`.
#
# See `Onyx::REST::Rescuers::Standard`.
abstract class Onyx::REST::Rescuer(T)
  include HTTP::Handler

  # A handler to call when a error is rescued.
  property handler : HTTP::Handler?

  # Initialize with a *handler* to call when a error is rescued.
  def initialize(@handler : HTTP::Handler? = nil)
  end

  def call(context)
    call_next(context)
  rescue error : T
    process(context, error)

    if handler = @handler
      before_handler(context, error)
      handler.call(context)
    else
      fallback(context, error)
    end
  end

  # Process the error before further handling. A good example is logging it.
  #
  # FIXME: Make abstract, so it raises if not defined in children. See https://github.com/crystal-lang/crystal/issues/6762.
  def process(context : HTTP::Server::Context, error : T)
    raise NotImplementedError.new(self)
  end

  # Called if `#handler` is set before it's called.
  def before_handler(context : HTTP::Server::Context, error : T)
    # Do nothing
  end

  # Called if no `#handler` is set.
  #
  # FIXME: Make abstract, so it raises if not defined in children. See https://github.com/crystal-lang/crystal/issues/6762.
  def fallback(context : HTTP::Server::Context, error : T)
    raise NotImplementedError.new(self)
  end
end
