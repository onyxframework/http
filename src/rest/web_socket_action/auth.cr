require "../ext/http/request/auth"

module Rest
  class WebSocketAction
    # Auth module for `WebSocketAction`. `auth!` closes the socket if unauthorized.
    module Auth
      def auth
        context.request.auth
      end

      def auth?
        auth.try &.auth
      end

      # Invoke `#auth.auth` or close the socket
      macro auth!
        def auth
          context.request.auth.not_nil!
        end

        def before
          if previous_def
            if context.request.auth.try(&.auth)
              true
            else
              socket.close("Unauthorized")
              false
            end
          end
        end
      end
    end
  end
end
