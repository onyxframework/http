require "./ext/http/request/auth"

module Prism
  # A versatile auth module.
  #
  # ```
  # class AuthableObject < Prism::Authable
  #   enum Scope
  #     User
  #     Admin
  #   end
  #
  #   getter! user : User?
  #   @user = nil
  #
  #   def initialize(@token : String?)
  #   end
  #
  #   def auth?(required_scope : Scope)
  #     @user = User.find(&.token.== @token)
  #     raise AuthorizationError.new("Wrong scope") if @user.scope < required_scope
  #   end
  # end
  #
  # struct MyAction < Prism::Action
  #   include Prism::Auth(AuthableObject)
  #
  #   def call
  #     # Check if auth object exists in current request
  #     # and answers #auth with :admin argument
  #     if auth?(:admin)
  #       auth.user # It would return an admin User instance
  #     else
  #       halt!(401)
  #     end
  #   end
  # end
  # ```
  module Auth(AuthableType)
    # Return a non-nil auth object contained in the request, otherwise raise. See `HTTP::Request.auth`.
    macro auth
      context.request.auth.not_nil!.as(AuthableType)
    end

    # Safe auth check. Returns nil if `context.request.auth` is empty.
    macro auth?(*args, **nargs)
      context.request.auth.try &.as(AuthableType).auth?({{ *args }}{{ ", ".id if nargs.size > 0 }}{{ **nargs }})
    end
  end
end
