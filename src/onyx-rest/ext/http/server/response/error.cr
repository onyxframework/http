module HTTP
  class Server
    class Response
      # A rescued error which is likely to be put into the response.
      property error : Exception?
    end
  end
end
