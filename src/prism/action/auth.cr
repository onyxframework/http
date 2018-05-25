require "../ext/http/request/auth"

module Prism
  abstract struct Action
    # Auth module for `Prism::Action`.
    #
    # ```
    # struct MyAction < Prism::Action
    #   include Auth
    #
    #   def call
    #     if auth?    # Check if auth object exists in current request and answers #auth
    #       auth.user # It will return a User instance
    #     else
    #       halt!(401)
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

      # Invoke `context.request.auth.auth` in `before` callback and do `halt!(401)` if it returns falsey value.
      macro auth!
        before do
          context.request.auth.try(&.auth) || halt!(401)
        end
      end
    end
  end
end
