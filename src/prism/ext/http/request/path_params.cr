module HTTP
  class Request
    @path_params : Hash(String, String)?
    # A hash containing path params (extracted from the request's path). It's automatically set when routing with `Prism::Router`.
    #
    # For example, request with path `"/user/42/edit"` routed with `put "/user/:id/edit"` will have `{"id" => "42"}` path params.
    getter path_params

    # :nodoc:
    setter path_params
  end
end
