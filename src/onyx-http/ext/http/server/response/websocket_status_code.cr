require "http/server/response"

class HTTP::Server::Response
  # Status code for websocket connection.
  property websocket_status_code : Int32 | Nil

  def reset
    previous_def
    @websocket_status_code = nil
  end
end
