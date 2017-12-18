require "http/server/handler"

module Prism
  # `HTTP::Handler` which calls the *proc* on `#call`.
  #
  # ```
  # require "prism/proc_handler"
  # secret = Prism::ProcHandler.new do |handler, context|
  #   if context.request.query_params.to_h["secret"]?.try &.== ENV["SECRET"]
  #     handler.call_next(context)
  #   end
  # end
  # ```
  class ProcHandler
    include HTTP::Handler

    @proc : ::Proc(self, HTTP::Server::Context, Void)

    # Initialize a new `ProcHandler` which will call *proc* in `#call`.
    # If the *proc* result is a falsey value, stop the further execution.
    def initialize(&proc : self, HTTP::Server::Context -> _)
      @proc = proc
    end

    # :nodoc:
    def call(context)
      @proc.call(self, context)
    end
  end
end
