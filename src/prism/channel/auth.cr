require "../auth"

module Prism
  module Channel
    # A `Channel` module which adds `authenticate` and `authorize` macro, which try to auth* in the before callback.
    #
    # ```
    # class MyChannel
    #   include Prism::Channel
    #   include Prism::Channel::Auth(Authenticator)
    #
    #   # Would try to call `auth?.try &.authenticate(:user)`
    #   # in before callback, close socket with "Unauthenticated" message otherwise
    #   authenticate :user
    #
    #   # Would try to call `auth?.try &.authorize(permissions: {:create_posts})`
    #   # in before callback, close socket with "Unauthorized" message otherwise
    #   authorize permissions: {:create_posts}
    #
    #   def on_open
    #     auth.user # It's guaranteed to be not nil
    #   end
    # end
    # ```
    module Auth(Authenticator)
      include Prism::Auth(Authenticator)

      macro authenticate(*args, **nargs)
        before do
          auth?.try &.authenticate({{ *args }}{{ ", ".id if args.size > 0 && nargs.size > 0 }}{{ **nargs }}) || (socket.close("Unauthenticated"); false)
        end
      end

      macro authorize(*args, **nargs)
        before do
          auth?.try &.authorize({{ *args }}{{ ", ".id if args.size > 0 && nargs.size > 0 }}{{ **nargs }}) || (socket.close("Unauthorized"); false)
        end
      end
    end
  end
end
