require "http/server"
require "json"

module Rest
  # A callable WebSocket Action.
  #
  # ```
  # require "rest/web_socket_action"
  #
  # class UserNotifications < Rest::WebSocketAction
  #   include Auth
  #   include Params
  #
  #   # Will close the socket if unauthorized
  #   auth!
  #
  #   # Will close the socket on validation error
  #   params do
  #     param :foo, String?
  #   end
  #
  #   def self.notify(user : User, payload : String)
  #     if socket = @@subscribtions[user]?
  #       socket.notify(payload)
  #     end
  #   end
  #
  #   def on_open
  #     @@subscribtions[auth.user] = self
  #   end
  #
  #   def notify(payload : String)
  #     socket.send(payload)
  #   end
  #
  #   def on_close
  #     @@subscribtions[auth.user] = nil
  #   end
  # end
  #
  # require "rest/router"
  #
  # router = Rest::Router.new do |r|
  #   r.ws "/notifications" do |socket, env|
  #     UserNotifications.call(socket, env)
  #   end
  # end
  #
  # # Later in the code
  #
  # UserNotifications.notify(user, "You've got a message!") # Damn it's cool
  # ```
  class WebSocketAction
    # Called once when a new socket is opened.
    def on_open
    end

    # Called when the socket receives a message from client.
    def on_message(message)
    end

    # Called when the socket receives a binary message from client.
    def on_binary(binary)
    end

    # Called when the socket receives a PING message from client.
    def on_ping
      socket.send("PONG")
    end

    # Called when the socket receives a PONG message from client.
    def on_pong
    end

    # Called once when the socket closes.
    def on_close
    end

    # Initialize a new instance and invoke `#call_with_callbacks` on it.
    def self.call(socket : HTTP::WebSocket, context : HTTP::Server::Context)
      new(socket, context).call_with_callbacks
    end

    # Call `#on_open` and bind to the `socket`'s events. Read more @ [API docs](https://crystal-lang.org/api/0.23.1/HTTP/WebSocket.html).
    def call
      on_open

      socket.on_message do |message|
        on_message(message)
      end

      socket.on_binary do |binary|
        on_binary(binary)
      end

      socket.on_ping do
        on_ping
      end

      socket.on_pong do
        on_pong
      end

      socket.on_close do
        on_close
      end
    end

    # :nodoc:
    def call_with_callbacks
      before && around { call } && after
    end

    # Before `#call` callback.
    # Should return truthy value or the call sequence would halt.
    #
    # OPTIMIZE: See [this issue](https://github.com/crystal-lang/crystal/issues/5203).
    def before
      # See definition below
    end

    macro inherited
      def before
        true
      end
    end

    # Around `#call` wrapper.
    # If returns falsey value, `#after` is not called.
    def around(&block)
      yield
      true
    end

    # After `#call` callback.
    # NOTE: Remeber that once the body is printed, the request cannot be modified.
    def after
    end

    getter context : ::HTTP::Server::Context
    getter socket : HTTP::WebSocket

    # :nodoc:
    def initialize(@socket, @context)
    end
  end
end

require "./web_socket_action/*"
