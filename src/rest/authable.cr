module Rest
  # An inheriting class will be marked as auth(*enticate*)able.
  #
  # ```
  # require "rest/authable"
  #
  # class Auth < Rest::Authable
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
    abstract def auth
  end
end
