require "../../../authenticator"

module HTTP
  class Request
    # An object containing auth data. It should be set by the developer. See `Prism::Action::Auth` and `Prism::Channel::Auth`.
    property auth : Prism::Authenticator? = nil
  end
end
