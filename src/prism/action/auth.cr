require "../auth"

module Prism
  module Action
    # An `Action` module which adds `auth!` macro, attempting to do auth in before callback.
    #
    # ```
    # struct StrictAction
    #   include Prism::Action
    #   include Prism::Action::Auth(AuthableObject)
    #
    #   auth!(:admin) # Would try to auth before call, halt otherwise
    #
    #   def call
    #     auth.user
    #   end
    # end
    # ```
    module Auth(AuthableType)
      include Prism::Auth(AuthableType)

      # Invoke `auth?` in `before` callback.
      #
      # Possible scenarios:
      # * `auth?` returns truthy value - the call continues;
      # * `auth?` returns falsey value - the call halts with 401 code;
      # * `auth?` raises `Authable::AuthenticationError` - the call halts with 401 code and message;
      # * `auth?` raises `Authable::AuthorizationError` - the call halts with 403 code and message.
      macro auth!(*args, **nargs)
        before do
          begin
            auth?({{ *args }}{{ ", ".id if nargs.size > 0 }}{{ **nargs }}) || raise Authable::AuthenticationError.new
          rescue e : Authable::AuthenticationError
            halt!(401, "#{e.message}")
          rescue e : Authable::AuthorizationError
            halt!(403, "#{e.message}")
          end
        end
      end
    end
  end
end
