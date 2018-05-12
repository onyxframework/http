require "../ext/http/request/auth"

module Prism
  class Channel
    # Auth module for `Channel`.
    #
    # ```
    # class MyChannel < Prism::Channel
    #   include Auth
    #
    #   def on_open
    #     if auth            # Check if auth object exists in current request
    #       user = auth.auth # Call #auth on this object, it should return a User instance
    #     else
    #       socket.close("Unauthorized")
    #     end
    #   end
    # end
    # ```
    module Auth
      # Return an auth object contained in the request. See `HTTP::Request.auth`.
      def auth
        context.request.auth
      end

      # Safe auth check. Returns nil if auth is empty.
      def auth?
        auth.try &.auth
      end

      # Invoke `#auth.auth` in `before` callback and close socket if it returns falsey value. `#auth` will return non-nil value from now.
      macro auth!
        def auth
          context.request.auth.not_nil!
        end

        before do
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
