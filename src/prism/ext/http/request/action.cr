require "http/server"
require "http/web_socket"

module HTTP
  class Request
    property action : ::Proc(HTTP::Server::Context, Nil) | HTTP::WebSocketHandler | Nil
  end
end
