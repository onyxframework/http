module HTTP
  class Server
    class Response
      # A string which is likely to be appended to the response body.
      # Usually set when an `Onyx::REST::Router` path proc returns a `String` value.
      property text : String?
    end
  end
end
