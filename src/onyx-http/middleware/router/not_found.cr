module Onyx::HTTP::Middleware
  class Router
    # Raised if route is not found for this request.
    # The default status code is 404. See https://httpstatuses.com/404.
    class NotFound < Error(404)
    end
  end
end
