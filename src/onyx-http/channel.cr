require "http/web_socket"
require "./endpoint"

# A websocket HTTP Channel.
#
# Channel instance is bind to a websocket instance, calling `#on_open`, `#on_message`,
# `#on_binary`, `#on_ping`, `#on_pong` and `#on_close` callbacks
# on according socket event. You are expected to re-define these methods.
#
# Channel includes the `Endpoint` module.
#
# ## Params
#
# Channel params can be defined with the `Endpoint.params` macro. The params are
# checked **before** the request is upgraded to a websocket, raising a default 400
# HTTP error if something is wrong.
#
# ## Errors
#
# Channel errors can be defined with the `Endpoint.errors` macro. They can be raised
# when the request is not upgraded yet (by overriding default `#call` method or in callbacks),
# or when it is already a websocket.
#
# Some considertations when raising when already upgraded:
#
# * Error codes must be in 4000-4999 range to conform with [standards](https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent#Properties)
# * Error message length must be less than or equal to 123 characters
# * `HTTP::Error`s are rescued and handled internally in a `Channel`,
# properly closing the socket, so you do not need a rescuer there
#
# ## Example
#
# ```
# class Channels::Echo
#   include Onyx::HTTP::Channel
#
#   params do
#     query do
#       # Would raise 400 HTTP error before upgrading if username is missing
#       type username : String
#
#       # Would raise 400 HTTP error before upgrading if secret is missing or of invalid type
#       type secret : Int32
#     end
#   end
#
#   errors do
#     # Expected to be raised before the request is upgraded
#     type UsernameTaken(403)
#
#     # Expected to be raised when the request is already upgraded to a websocket
#     type InvalidSecret(4003)
#   end
#
#   before do
#     # Return 403 HTTP error without upgrading to a websocket
#     raise UsernameTaken.new if params.query.username == "Vlad"
#   end
#
#   def on_open
#     unless params.query.secret == 42
#       # Close websocket with 4003 code and "Invalid Secret" reason
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
#   ws "/" do |context|
#     channel.call(context)
#   end
# end
# ```
module Onyx::HTTP::Channel
  include Endpoint

  # By default calls `#upgrade`, which upgrades the request to
  # a websocket and then calls `#bind`.
  def call
    upgrade do |socket|
      bind(socket)
    end
  end

  macro included
    include Onyx::HTTP::Endpoint

    def self.call(context)
      instance = new(context)
      instance.with_callbacks { instance.call }
    end
  end

  protected getter! socket : ::HTTP::WebSocket

  # Called once when a new socket is opened.
  protected def on_open
  end

  # Called when the socket receives a message from client.
  protected def on_message(message)
  end

  # Called when the socket receives a binary message from client.
  def on_binary(binary)
  end

  # Called when the socket receives a PING message from client.
  # Sends `"PONG"` by default.
  protected def on_ping
    socket.send("PONG")
  end

  # Called when the socket receives a PONG message from client.
  protected def on_pong
  end

  # Called once when the socket closes.
  protected def on_close
  end

  # Call `#on_open` and bind to the `socket`'s events. Read more in [Crystal API docs](https://crystal-lang.org/api/latest/HTTP/WebSocket.html).
  # Rescues errors, gracefully closing the websocket with according error code.
  protected def bind(socket)
    @socket = socket

    wrap { on_open }

    socket.on_message do |message|
      wrap { on_message(message) }
    end

    socket.on_binary do |binary|
      wrap { on_binary(binary) }
    end

    socket.on_ping do
      wrap { on_ping }
    end

    socket.on_pong do
      wrap { on_pong }
    end

    socket.on_close do
      context.response.status_code = 1000 if context.response.status_code == 101
      on_close
    end
  end

  protected def wrap(&block)
    begin
      yield
    rescue error : Exception
      if error.is_a?(HTTP::Error)
        context.response.status_code = error.code
        code = error.code.to_i16
        message = error.status_message
      else
        context.response.status_code = 1011
        code = 1011_i16
        message = "Exception"
      end

      raw = uninitialized UInt8[2]
      IO::ByteFormat::BigEndian.encode(code, raw.to_slice)
      socket.close(String.new(raw.to_slice) + message)

      raise error unless error.is_a?(HTTP::Error)
    end
  end

  protected def upgrade(&proc : ::HTTP::WebSocket ->)
    if websocket_upgrade_request?(context.request)
      response = context.response

      version = context.request.headers["Sec-WebSocket-Version"]?
      unless version == ::HTTP::WebSocket::Protocol::VERSION
        response.headers["Sec-WebSocket-Version"] = ::HTTP::WebSocket::Protocol::VERSION
        raise Middleware::Router::UpgradeRequired.new
      end

      key = context.request.headers["Sec-WebSocket-Key"]?
      raise Middleware::Router::BadRequest.new("Sec-WebSocket-Key header is missing") unless key

      accept_code = ::HTTP::WebSocket::Protocol.key_challenge(key)

      response.status_code = 101
      response.headers["Upgrade"] = "websocket"
      response.headers["Connection"] = "Upgrade"
      response.headers["Sec-WebSocket-Accept"] = accept_code

      response.upgrade do |io|
        socket = ::HTTP::WebSocket.new(io)
        proc.call(socket)
        socket.run
      ensure
        io.close
      end
    else
      raise Middleware::Router::UpgradeRequired.new
    end
  end

  protected def websocket_upgrade_request?(request)
    return false unless upgrade = request.headers["Upgrade"]?
    return false unless upgrade.compare("websocket", case_insensitive: true) == 0

    request.headers.includes_word?("Connection", "Upgrade")
  end
end
