require "http/server/context"
require "http/web_socket"
require "./channel/*"

class Atom
  # A callable websocket Channel with [Params](https://github.com/vladfaust/params.cr) included.
  #
  # Channels have special `.params` definition syntax, it's basically a convenient wrapper
  # over default NamedTuple syntax of [Params](https://github.com/vladfaust/params.cr).
  #
  # ```
  # class UserNotifications
  #   include Atom::Channel
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
  # router = Atom::Handlers::Router.new do
  #   ws "/notifications" do |socket, env|
  #     UserNotifications.subscribe(socket, env)
  #     # Or
  #     UserNotifications.call(socket, env)
  #   end
  #   # Or
  #   ws "/notifications", UserNotifications
  # end
  #
  # # Later in the code
  #
  # UserNotifications.notify(user, "You've got a message!")
  # ```
  module Channel
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
      {% raise "#{@type} must be a Class to include Atom::Channel" unless @type < Reference %}

      # Initialize a new instance and invoke `#subscribe`.
      def self.subscribe(socket : HTTP::WebSocket, context : HTTP::Server::Context)
        new(socket, context).subscribe
      end

      # ditto
      def self.call(socket, context)
        subscribe(socket, context)
      end

      # May upon on `.params` parsing.
      class_getter max_body_size : UInt64 = UInt64.new(8 * 1024 ** 2)

      # You can change `.max_body_size` per channel basis.
      #
      # ```
      # struct MyChannel
      #   include Atom::Channel
      #   max_body_size = 1 * 1024 ** 3 # 1 GB
      # end
      # ```
      protected class_setter max_body_size
    end

    # Call `#on_open` and bind to the `socket`'s events. Read more in [Crystal API docs](https://crystal-lang.org/api/latest/HTTP/WebSocket.html).
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

    protected getter context, socket

    def initialize(@socket : HTTP::Server::Context, @context : HTTP::WebSocket)
    end
  end
end
