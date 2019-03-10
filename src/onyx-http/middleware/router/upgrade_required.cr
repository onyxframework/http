module Onyx::HTTP::Middleware
  class Router
    # Raised when router has as `ws` route for this path.
    # The `"Upgrade"` header is set to `"Websocket"` in `Middleware::Router`.
    # The default status code is 426. See https://httpstatuses.com/426.
    class UpgradeRequired < Error(426)
    end
  end
end
