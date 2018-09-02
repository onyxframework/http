require "./ext/http/request/path_params"
require "./ext/null"
require "./params/**"

# Request params typecasting and validation module.
#
# Extracts params from (nearly) all possible sources and casts them accordingly (invoking `Type.from_param`) into a `NamedTuple`.
#
# ```
# class SimpleAction
#   include Prism::Params
#
#   params do
#     type foo : Int32? # Equivalent of `Int32 | Nil`
#     type name : String | Null, validate: {size: {min: 3}} # Null is different from Nil
#     type the_time : Time? # the_time, the-time and theTime keys are accepted
#     type bar : nilable: true do # Nested params are supported too
#       type baz :do
#         type qux : String?
#         type qax : Array(String)? # Yep, arrays
#       end
#
#       type quux : Int32
#     end
#   end
#
#   def self.call(context)
#     params = parse_params(context,
#       limit: 1.gb,         # Defaults to 8 MB
#       preserve_body: true, # Defaults to false
#     )
#
#     p params[:foo].class
#     # => Int32?
#
#     p params[:name].class
#     # => String
#
#     p params[:the_time].class
#     # => Time?
#
#     p params[:bar]?.try &.[:baz][:qux].class
#     # => String?
#
#     p params[:bar]?.try &.[:baz][:qax].class
#     # => Array(String)?
#   end
# end
# ```
#
# NOTE: Params can be accessed both by `String` and `Symbol` keys.
#
# Params parsing order (latter rewrites previous):
#
# 1. Path params (note that when parsing path params, only keys the same as params' names are looked up, e.g. `"the_time"`);
# 2. Request query params (.e.g "/?foo=42&theTime=0");
# 3. Multipart form data (only if `"Content-Type"` is `"multipart/form-data"`);
# 4. Body params (only if `"Content-Type"` is `"application/x-www-form-urlencoded"`);
# 5. JSON body (only if `"Content-Type"` is `"application/json"`).
#
# If you want to implement your own type casting, extend it with `.from_param` method (see `Int.from_param` for example).
#
# `Prism::Action::Params` and `Prism::Channel::Params` modules can be included to automatically add `parse_params` into `#before` callback:
#
# ```
# struct MyPrismAction
#   include Prism::Action
#   include Prism::Action::Params
#
#   params do
#     type id : Int32
#   end
#
#   def call
#     p params[:id].class # => Int32
#   end
# end
# ```
module Prism::Params
  include Validation

  # An **essential** params definition block.
  macro params(&block)
    INTERNAL__PRISM_PARAMS = [] of NamedTuple
    INTERNAL__PRISM_PARAMS_PARENTS = {current_value: [] of Symbol, nilable: {} of Array(Symbol) => Bool}

    {{yield.id}}

    define_params_tuple
    define_param_type
    define_parse_params
  end
end
