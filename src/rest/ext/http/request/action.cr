module HTTP
  class Request
    property action : Proc(HTTP::Server::Context, Nil)?
  end
end
