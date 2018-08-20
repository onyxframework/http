module Prism
  # An auth container.
  #
  # ```
  # class Auth < Prism::Authable
  #   getter user : User?
  #
  #   def initialize(@token : String?)
  #   end
  #
  #   def auth?
  #     @user = User.find(&.token.== @token)
  #   end
  # end
  # ```
  abstract class Authable
    class AuthenticationError < Exception
    end

    class AuthorizationError < Exception
    end

    abstract def auth?(*args, **nargs)
  end
end
