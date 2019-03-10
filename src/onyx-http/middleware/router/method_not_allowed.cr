module Onyx::HTTP::Middleware
  class Router
    # Raised when router has methods for this path other than requested.
    # The `"Allow"` header is set to the list of allowed methods in `Middleware::Router`.
    # The default status code is 405. See https://httpstatuses.com/405.
    class MethodNotAllowed < Error(405)
    end
  end
end
