require "params"

module Atom::Action
  # Optional params definition macro. It's powered by [Params](https://github.com/vladfaust/params.cr) shard.
  #
  # However, to avoid original cumbersome NamedTuple syntax, a new simpler syntax is implemented:
  #
  # ```
  # params do
  #   type id : Int32
  #   type foo : Array(String) | Nil
  #   type user, nilable: true do
  #     type name : String
  #     type email : String?
  #   end
  # end
  #
  # # Is essentialy the same as
  #
  # Params.mapping({
  #   id:   Int32,
  #   foo:  Array(String) | Nil,
  #   user: {
  #     name:  String,
  #     email: String?,
  #   } | Nil,
  # })
  # ```
  #
  # Params can be accessed by `#params` getter. (e.g. `params.id`).
  macro params(&block)
    struct Params
      ::Params.mapping({
        {{run("../ext/params/type_macro_parser", yield.id)}}
      })
    end

    getter params : Params

    def initialize(@context : HTTP::Server::Context)
      @params = Params.new(context.request, self.class.max_body_size, self.class.preserve_body)
    end
  end
end
