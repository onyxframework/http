require "../../../authable"

module HTTP
  class Request
    property auth : Rest::Authable? = nil
  end
end
