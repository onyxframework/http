require "../ext/http/request/auth"

module Rest
  struct Action
    module Auth
      def auth
        context.request.auth
      end

      # Invoke `#auth.auth` and `halt!(401)` if returns falsey value.
      macro auth!
        def auth
          context.request.auth.not_nil!
        end

        def before
          if previous_def
            context.request.auth.try(&.auth) || halt!(401)
          end
        end
      end
    end
  end
end
