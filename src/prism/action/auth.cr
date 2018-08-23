require "../auth"

module Prism
  module Action
    # An `Action` module which adds `authenticate` and `authorize` macro, which try to auth* in the before callback.
    #
    # ```
    # struct StrictAction
    #   include Prism::Action
    #   include Prism::Action::Auth(Authenticator)
    #
    #   # Would try to call `auth?.try &.authenticate(:user)`
    #   # in before callback, `halt!(401)` otherwise
    #   authenticate :user
    #
    #   # Would try to call `auth?.try &.authorize(permissions: {:create_posts})`
    #   # in before callback, `halt!(403)` otherwise
    #   authorize permissions: {:create_posts}
    #
    #   def call
    #     auth.user # It's guaranteed to be not nil
    #   end
    # end
    # ```
    module Auth(Authenticator)
      include Prism::Auth(Authenticator)

      macro authenticate(*args, **nargs)
        before do
          auth?.try &.authenticate({{ *args }}{{ ", ".id if args.size > 0 && nargs.size > 0 }}{{ **nargs }}) || halt!(401)
        end
      end

      macro authorize(*args, **nargs)
        before do
          auth?.try &.authorize({{ *args }}{{ ", ".id if args.size > 0 && nargs.size > 0 }}{{ **nargs }}) || halt!(403)
        end
      end
    end
  end
end
