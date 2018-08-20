require "http/server"
require "json"
require "callbacks"
require "./channel/*"

module Prism
  # A callable websocket Channel with [Callbacks](https://github.com/vladfaust/callbacks.cr) module included.
  #
  # ```
  # class UserNotifications
  #   include Prism::Channel
  #   include Prism::Channel::Auth
  #   include Prism::Channel::Params
  #
  #   # Will close the socket if unauthorized
  #   auth!
  #
  #   # Will close the socket on params validation error
  #   params do
  #     param :foo, String?
  #   end
  #
  #   def self.notify(user : User, payload : String)
  #     if socket = @@subscriptions[user]?
  #       socket.notify(payload)
  #     end
  #   end
  #
  #   def on_open
  #     @@subscriptions[auth.user] = self
  #   end
  #
  #   def notify(payload : String)
  #     socket.send(payload)
  #   end
  #
  #   def on_close
  #     @@subscriptions[auth.user] = nil
  #   end
  # end
  #
  # router = Prism::Router.new do
  #   ws "/notifications" do |socket, env|
  #     UserNotifications.subscribe(socket, env)
  #     # Or
  #     UserNotifications.call(socket, env)
  #   end
  # end
  #
  # # Later in the code
  #
  # UserNotifications.notify(user, "You've got a message!")
  # ```
  module Channel
    include Callbacks

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

    macro included
      # Initialize a new instance and invoke `#subscribe_with_callbacks` on it.
      def self.subscribe(socket : HTTP::WebSocket, context : HTTP::Server::Context)
        new(socket, context).subscribe_with_callbacks
      end

      # ditto
      def self.call(socket, context)
        subscribe(socket, context)
      end
    end

    # Call `#on_open` and bind to the `socket`'s events. Read more in [Crystal API docs](https://crystal-lang.org/api/0.23.1/HTTP/WebSocket.html).
    def subscribe
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

    # Subscribe to channel with [callbacks](https://github.com/vladfaust/callbacks.cr).
    def subscribe_with_callbacks
      with_callbacks { subscribe }
    end

    getter context : ::HTTP::Server::Context
    getter socket : HTTP::WebSocket

    # :nodoc:
    def initialize(@socket, @context)
    end
  end
end

require "./channel/*"
