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
    #     if auth?    # Check if auth object exists in current request and answers #auth
    #       auth.user # It will return a User instance
    #     else
    #       socket.close("Unauthorized")
    #     end
    #   end
    # end
    # ```
    module Auth
      # Return a non-nil auth object contained in the request, otherwise raise. See `HTTP::Request.auth`.
      def auth
        context.request.auth.not_nil!
      end

      # Safe auth check. Returns nil if auth is empty.
      def auth?
        context.request.auth.try &.auth
      end

      # Invoke `context.request.auth.auth` in `before` callback and close socket if it returns falsey value.
      macro auth!
        before do
          context.request.auth.try(&.auth) || (socket.close("Unauthorized"); false)
        end
      end
    end
  end
end
