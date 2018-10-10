require "../../../../view"

module HTTP
  class Server
    class Response
      # A (presumable) renderable view for this response.
      getter view : Atom::View | Nil

      # :nodoc:
      setter view
    end
  end
end
