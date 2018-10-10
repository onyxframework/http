module HTTP
  class Server
    class Context
      # A Proc to run. Usually set by `Atom::Handlers::Router`.
      getter proc : Proc(self, Nil) | HTTP::WebSocketHandler | Nil

      # :nodoc:
      setter proc
    end
  end
end
