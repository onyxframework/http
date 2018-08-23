module Prism
  # An abstract auth container.
  #
  # It doesn't have any functionality, but marks an including type as eligible for an auth object at `context.request.auth`.
  #
  # However, as seen at `Action::Auth` and `Channel::Auth`, an including type is likely to implement `authenticate` and `authorize` methods.
  #
  # ```
  # class Authenticator
  #   include Prism::Authenticator
  #
  #   getter! user : User?
  #
  #   def initialize(@token : String?)
  #   end
  #
  #   def authenticate
  #     @user ||= User.find(&.token.== @token)
  #   end
  # end
  # ```
  module Authenticator
  end
end
