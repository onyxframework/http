require "../../../authable"

module HTTP
  class Request
    # An object containing auth data. It should be set by the developer. See `Prism::Action::Auth` and `Prism::Channel::Auth`.
    property auth : Prism::Authable? = nil
  end
end
