require "params"

module Atom::Channel
  # Optional params definition macro. See `Action.params` for details.
  # Params can be accessed by `#params` getter. (e.g. `params.id`).
  macro params(&block)
    struct Params
      ::Params.mapping({
        {{run("../ext/params/type_macro_parser", yield.id)}}
      })
    end

    getter params : Params

    def initialize(@socket : HTTP::Server::Context, @context : HTTP::WebSocket)
      @params = Params.new(context.request, self.class.max_body_size, false)
    end
  end
end
