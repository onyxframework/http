require "../ext/http/request/auth"

module Prism
  struct Action
    module Auth
      def auth
        context.request.auth
      end

      def auth?
        auth.try &.auth
      end

      # Invoke `#auth.auth` and `halt!(401)` if returns falsey value.
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
