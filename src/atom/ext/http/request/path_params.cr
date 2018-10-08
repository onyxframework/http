module HTTP
  class Request
    # A hash containing path params (extracted from the request's path). It's automatically set when routing with `Atom::Handlers::Router`.
    #
    # For example, request with path `"/user/42/edit"` routed with `put "/user/:id/edit"` will have `{"id" => "42"}` path params.
    getter path_params : Hash(String, String) | Nil = nil

    # :nodoc:
    setter path_params
  end
end
