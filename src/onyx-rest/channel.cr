require "http/web_socket"

require "./endpoint"
require "./channel/*"

# A websocket REST Channel.
#
# Channel instance is bind to a websocket instance, calling `#on_open`, `#on_message`,
# `#on_binary`, `#on_ping`, `#on_pong` and `#on_close` callbacks
# on according socket event. You are expected to re-define these methods.
#
# Channel includes the `Endpoint` module.
# Channel params can be defined with the `Endpoint.params` macro (param errors have code 4000).
#
# ## Errors
#
# Channel errors can be defined with the `Endpoint.errors` macro.
# Some considertations:
#
# * Error codes must be in 4000-4999 range to conform with [standards](https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent#Properties)
# * Error message length must be less than or equal to 123 characters
# * `REST::Error`s are rescued and handled internally in a `Channel`,
# properly closing the socket, so you do not need a rescuer there
#
# ## Example
#
# ```
# class Channels::Echo
#   include Onyx::REST::Channel
#
#   params do
#     query do
#       type secret : Int32
#     end
#   end
#
#   errors do
#     type InvalidSecret(4003)
#   end
#
#   def on_open
#     unless params.query.secret == 42
#       # Close socket with 4003 code and "Invalid Secret" reason
#       raise InvalidSecret.new
#     end
#   end
#
#   def on_message(message)
#     socket.send(message)
#   end
# end
# ```
#
# Router example:
#
# ```
# router = Onyx::HTTP::Router.new do
#   ws "/", Channels::Echo
#   # Equivalent of
#   ws "/" do |socket, context|
#     Channels::Echo.bind(socket, context)
#   end
# end
# ```
module Onyx::REST::Channel
  include Endpoint

  PARAMS_ERROR_CODE = 4000

  protected getter! socket : ::HTTP::WebSocket

  macro included
    # Initialize a new instance and invoke `#bind`.
    def self.bind(socket : ::HTTP::WebSocket, context : ::HTTP::Server::Context)
      new(context).bind(socket)
    rescue error : Onyx::REST::Error
      raw = uninitialized UInt8[2]
      IO::ByteFormat::BigEndian.encode(error.code.to_i16, raw.to_slice)
      socket.close(String.new(raw.to_slice) + "#{error.message}")
    end
  end

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
  # Sends `"PONG"` by default.
  def on_ping
    socket.send("PONG")
  end

  # Called when the socket receives a PONG message from client.
  def on_pong
  end

  # Called once when the socket closes.
  def on_close
  end

  # Call `#on_open` and bind to the `socket`'s events. Read more in [Crystal API docs](https://crystal-lang.org/api/latest/HTTP/WebSocket.html).
  def bind(socket)
    @socket = socket

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
end
