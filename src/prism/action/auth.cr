require "../ext/http/request/auth"

module Prism
  struct Action
    # Auth module for `Prism::Action`.
    #
    # ```
    # struct MyAction < Prism::Action
    #   include Auth
    #
    #   def call
    #     if auth            # Check if auth object exists in current request
    #       user = auth.auth # Call #auth on this object, it should return a User instance
    #     else
    #       halt!(401)
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

      # Invoke `#auth.auth` in `before` callback and do `halt!(401)` if it returns falsey value. `#auth` will return non-nil value from now.
      macro auth!
        def auth
          context.request.auth.not_nil!
        end

        before do
          context.request.auth.try(&.auth) || halt!(401)
        end
      end
    end
  end
end
