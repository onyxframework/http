module Onyx::HTTP::Middleware
  class Router
    class WebSocketHandler
      include ::HTTP::Handler

      def initialize(&@proc : ::HTTP::WebSocket, ::HTTP::Server::Context ->)
      end

      def call(context)
        if websocket_upgrade_request?(context.request)
          response = context.response

          version = context.request.headers["Sec-WebSocket-Version"]?
          unless version == ::HTTP::WebSocket::Protocol::VERSION
            response.headers["Sec-WebSocket-Version"] = ::HTTP::WebSocket::Protocol::VERSION
            raise UpgradeRequired.new
          end

          key = context.request.headers["Sec-WebSocket-Key"]?
          raise BadRequest.new("Sec-WebSocket-Key header is missing") unless key

          accept_code = ::HTTP::WebSocket::Protocol.key_challenge(key)

          response.status_code = 101
          response.headers["Upgrade"] = "websocket"
          response.headers["Connection"] = "Upgrade"
          response.headers["Sec-WebSocket-Accept"] = accept_code

          response.upgrade do |io|
            socket = ::HTTP::WebSocket.new(io)
            @proc.call(socket, context)
            socket.run
          rescue error : Exception
            if error.is_a?(HTTP::Error)
              context.response.websocket_status_code = error.code
              code = error.code.to_i16
              message = error.status_message
            else
              context.response.websocket_status_code = 1011
              code = 1011_i16
              message = "Exception"
            end

            raw = uninitialized UInt8[2]
            IO::ByteFormat::BigEndian.encode(code, raw.to_slice)
            socket.not_nil!.close(String.new(raw.to_slice) + message)

            raise error unless error.is_a?(HTTP::Error)
          end
        else
          raise UpgradeRequired.new
        end
      end

      protected def websocket_upgrade_request?(request)
        return false unless upgrade = request.headers["Upgrade"]?
        return false unless upgrade.compare("websocket", case_insensitive: true) == 0

        request.headers.includes_word?("Connection", "Upgrade")
      end
    end
  end
end
