require "http/server"
require "json"
require "callbacks"
require "params"
require "./channel/*"

module Prism
  # A callable websocket Channel with [Callbacks](https://github.com/vladfaust/callbacks.cr)
  # and [Params](https://github.com/vladfaust/params.cr) included.
  #
  # Params have special handy definition syntax, as seen in the example below:
  #
  # ```
  # class UserNotifications
  #   include Prism::Channel
  #
  #   params do
  #     type id : Int32
  #     type foo : Array(String) | Nil
  #     type user, nilable: true do
  #       type name : String
  #       type email : String?
  #     end
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

    # Optional params definition block. See `Action.params`.
    macro params(&block)
      ::Params.mapping({
        {{run("./ext/params/type_macro_parser", yield.id)}}
      })

      def self.new(socket, context)
        new(context.request, max_body_size, preserve_body).tap do |i|
          i.socket = socket
          i.context = context
        end
      end
    end

    macro included
      {% raise "#{@type} must be a Class to include Prism::Channel" unless @type < Reference %}

      # Initialize a new instance and invoke `#subscribe_with_callbacks` on it.
      def self.subscribe(socket : HTTP::WebSocket, context : HTTP::Server::Context)
        new(socket, context).subscribe_with_callbacks
      end

      # ditto
      def self.call(socket, context)
        subscribe(socket, context)
      end

      # Will **not** raise on exceed when reading from body in the `#call` method, however could raise on params parsing.
      class_getter max_body_size : UInt64 = UInt64.new(8 * 1024 ** 2)
      protected class_setter max_body_size

      # Change to `true` to preserve body upon params parsing.
      # Has effect only in cases when params are read from body.
      class_getter preserve_body : Bool = false
      protected class_setter preserve_body
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

    getter! context : ::HTTP::Server::Context, socket : HTTP::WebSocket
    protected setter context, socket

    # :nodoc:
    def initialize(@socket : ::HTTP::Server::Context, @context : HTTP::WebSocket)
    end
  end
end

require "./channel/*"
