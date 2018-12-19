module HTTP
  class Request
    # A request ID. Can be set by `Onyx::REST::RequestID`.
    property id : String | Nil = nil
  end
end
