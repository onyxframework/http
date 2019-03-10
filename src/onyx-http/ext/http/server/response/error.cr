require "http/server/response"

class HTTP::Server::Response
  # A rescued error which is likely to be put into the response output.
  property error : Exception?

  def reset
    previous_def
    @error = nil
  end
end
