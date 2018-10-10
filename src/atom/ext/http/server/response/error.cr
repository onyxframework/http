module HTTP
  class Server
    class Response
      # A error for this response.
      getter error : Exception | Nil

      # :nodoc:
      setter error
    end
  end
end
