require "http/server/handler"

class Atom
  module Handlers
    # Rescues `T` and calls *proc* passing the context and the error to it.
    #
    # ```
    # rescuer = Atom::Handlers::Rescuer(Exception) do |context, ex|
    #   context.respond_with_error(ex.message, 500)
    # end
    # ```
    class Rescuer(T)
      include HTTP::Handler

      @proc : ::Proc(HTTP::Server::Context, T, Void)

      def initialize(&@proc : HTTP::Server::Context, T -> _)
      end

      def call(context)
        call_next(context)
      rescue ex : T
        @proc.call(context, ex)
      end
    end
  end
end
