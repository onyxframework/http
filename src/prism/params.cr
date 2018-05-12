require "./params/**"

# Request params typecasting and validation module.
#
# Extracts params from (nearly) all possible sources and casts them accordingly (invoking `Type.from_param`) into a `NamedTuple`.
#
# ```
# require "prism/params"
#
# class SimpleAction
#   include Prism::Params
#
#   params do
#     param :foo, Int32?
#     param :name, String, validate: {size: {min: 3}}
#     param "kebab-case-time", Time?
#     param :bar, nilable: true do # Nested params are supported too
#       param :baz do
#         param :qux, String?
#       end
#
#       param :quux, Int32, proc: (quux : Int32) -> { quux * 2 }
#     end
#   end
#
#   def self.call(context)
#     params = parse_params(context, limit: 1.gb) # Limit is default to 8 MB
#
#     p params[:foo].class
#     # => Int32?
#
#     p params[:name].class
#     # => String
#
#     p params["kebab-case-time"].class
#     # => Time?
#
#     p params[:bar]?.try &.[:baz][:qux].class
#     # => String?
#   end
# end
# ```
#
# NOTE: Params can be accessed both by `String` and `Symbol` keys.
#
# Params parsing order (latter rewrites previous):
#
# 1. Path params (only if `"prism/ext/http/request/path_params"` is required **before** this file);
# 2. Request query params (.e.g "/?foo=42");
# 3. Multipart form data (only if `"Content-Type"` is `"multipart/form-data"`);
# 4. Body params (only if `"Content-Type"` is `"application/x-www-form-urlencoded"`);
# 5. JSON body (only if `"Content-Type"` is `"application/json"`).
#
# Parsing will replace original request body with its shrinked copy IO (defaults to 8 MB).
#
# If you want to implement your own type casting, extend it with `.from_param` method (see `Int32.from_param` for example).
#
# If included into `Prism::Action`, it will automatically inject `parse_params` into `Action#before` callback:
#
# ```
# require "prism/action"
# require "prism/action/params"
#
# struct MyPrismAction < Prism::Action
#   include Params
#
#   params do
#     param :id, Int32
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

    {{yield}}

    define_params_tuple
    define_param_type
    define_parse_params
  end
end
