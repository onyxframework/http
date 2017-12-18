require "../../../authable"

module HTTP
  class Request
    property auth : Prism::Authable? = nil
  end
end
