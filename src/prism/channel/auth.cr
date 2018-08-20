require "../auth"

module Prism
  class Channel
    # An `Channel` module which adds `auth!` macro, attempting to do auth in before callback.
    #
    # ```
    # class MyChannel < Prism::Channel
    #   include Prism::Channel::Auth(AuthableObject)
    #
    #   auth!(:admin)
    #
    #   def on_open
    #     auth.user
    #   end
    # end
    # ```
    module Auth(AuthableObject)
      include Prism::Auth(AuthableObject)

      # Invoke `auth?` in `before` callback.
      #
      # Possible scenarios:
      # * `auth?` returns truthy value - the call continues;
      # * `auth?` returns falsey value - the socket is closed with "Unauthenticated" message;
      # * `auth?` raises `Authable::AuthenticationError` or `Authable::AuthorizationError` - the socket is closed with custom message or "Unauthenticated" / "Unauthorized" if empty.
      macro auth!(*args, **nargs)
        before do
          begin
            auth?({{ *args }}{{ ", ".id if nargs.size > 0 }}{{ **nargs }}) || (raise Authable::AuthenticationError.new)
          rescue e : Authable::AuthenticationError
            socket.close(e.message ? "#{e.message}" : "Unauthenticated"); false
          rescue e : Authable::AuthorizationError
            socket.close(e.message ? "#{e.message}" : "Unauthorized"); false
          end
        end
      end
    end
  end
end
