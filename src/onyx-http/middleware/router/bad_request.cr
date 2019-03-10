module Onyx::HTTP::Middleware
  class Router
    # Raised when a requst is bad.
    # The default status code is 400. See https://httpstatuses.com/400.
    class BadRequest < Error(400)
    end
  end
end
