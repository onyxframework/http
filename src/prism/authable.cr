module Prism
  # An inheriting class will be marked as auth(*enticate*)able.
  #
  # ```
  # class Auth < Prism::Authable
  #   getter user : User?
  #
  #   def initialize(@token : String?)
  #   end
  #
  #   def auth
  #     @user = User.find(&.token.== @token)
  #   end
  # end
  # ```
  abstract class Authable
    # Must return truthy value to pass `auth!`. See `Prism::Action::Auth` and `Prism::Channel::Auth`.
    abstract def auth
  end
end
