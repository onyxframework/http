require "http/server"
require "http/web_socket"

module HTTP
  class Request
    @action : ::Proc(HTTP::Server::Context, Nil) | HTTP::WebSocketHandler | Nil

    # An action to call in this request. It's automatically injected into `Request` when routing with `Prism::Router`.
    getter action

    # :nodoc:
    setter action
  end
end
