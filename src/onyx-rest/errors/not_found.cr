class Onyx::REST
  # Known REST errors, usually rescued within the stack.
  module Errors
    # This error is raised internally when a route is not found.
    class NotFound < Error(404)
      # The HTTP method which was used in the request (e.g. "GET").
      getter method : String

      # The request path (e.g. "/foo").
      getter path : String

      # Call `super("Not Found")`.
      def initialize(@method : String, @path : String)
        super("Not Found")
      end

      # Return `{method: @method, path: @path}`.
      def payload
        {
          method: @method,
          path:   @path,
        }
      end
    end
  end
end
