require "./ext/http/request/auth"

module Prism
  # A versatile auth module.
  #
  # ```
  # class Authenticator
  #   include Prism::Authenticator
  #
  #   enum Scope
  #     User
  #     Admin
  #   end
  #
  #   def user
  #     user?.not_nil!
  #   end
  #
  #   def user?
  #     @user ||= User.find(&.token.== @token)
  #   end
  #
  #   def initialize(@token : String?)
  #   end
  # end
  #
  # struct MyAction
  #   include Prism::Action
  #   include Prism::Auth(Authenticator)
  #
  #   def call
  #     # Check if auth object exists in current request before
  #     if auth?.try &.user?
  #       auth.user # It would return a non-nil User instance
  #     else
  #       halt(401)
  #     end
  #   end
  # end
  # ```
  module Auth(Authenticator)
    # Return a non-nil authenticator object contained in the request, otherwise raise. See `HTTP::Request.auth`.
    macro auth
      context.request.auth.not_nil!.as(Authenticator)
    end

    # Safe authenticator object check. Returns nil if `context.request.auth` is empty.
    macro auth?
      context.request.auth.try &.as(Authenticator)
    end
  end
end
