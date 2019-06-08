require "http/server/response"
require "../../../../view"

class HTTP::Server::Response
  # A view to render.
  property view : Onyx::HTTP::View?

  def reset
    previous_def
    @view = nil
  end
end
