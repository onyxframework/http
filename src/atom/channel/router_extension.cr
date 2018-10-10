require "../handlers/router"

module Atom
  module Handlers
    class Router
      # Draw a WebSocket route for *path* instantiating *channel*. See `Channel`.
      #
      # A request is currently determined as websocket by `"Upgrade": "Websocket"` header.
      #
      # ```
      # router = Atom::Handlers::Router.new do
      #   ws "/foo/:bar", MyChannel
      # end
      # ```
      def ws(path, channel : Channel.class)
        add("/ws" + path, WebSocketProc.new { |s, c| MyChannel.call(s, c) }.as(Node))
      end
    end
  end
end
