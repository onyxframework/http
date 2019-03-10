require "../rescuer"
require "../../ext/http/server/response/error"

module Onyx::HTTP::Middleware
  module Rescuer
    # A rescuer which silently passes a error to the `#next_handler`.
    class Silent(T)
      include Rescuer(T)

      # Do nothing.
      def handle(context, error)
        # Do nothing
      end
    end
  end
end
