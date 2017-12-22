require "json"

require "./ext/from_s"
require "./ext/json/lexer"

require "./params/**"

# Request params access and validation module.
#
# Extracts params from (nearly) all possible sources and casts them accordingly (invoking `Type.from_s`) into a `NamedTuple`.
#
# ```
# require "prism/action/params"
#
# class SimpleAction
#   include Prism::Params
#
#   params do
#     param :foo, Int32?
#     param :name, String, validate: ->(name : String?) { name.size >= 3 }
#     param "kebab-case-time", Time?
#   end
#
#   def self.call(context)
#     params = parse_params(context)
#
#     p params[:foo].class
#     # => Int32?
#
#     p params[:name].class
#     # => String
#
#     p params["kebab-case-time"].class
#     # => Time?
#   end
# end
# ```
#
# NOTE: Params can be accessed both by `String` and `Symbol` keys.
#
# Params parsing order (latter rewrites previous):
#
# 1. Path params (only if `"prism/ext/http/request/path_params"` is required **before**)
# 2. Request query params
# 3. Multipart form data (only if `"Content-Type"` is `"multipart/form-data"`)
# 4. Body params (only if `"Content-Type"` is `"application/x-www-form-urlencoded"`)
# 5. JSON body (only if `"Content-Type"` is `"application/json"`)
#
# NOTE: If `"Content-Type"` header is  `"application/x-www-form-urlencoded"` or `"application/json"`, the request body will be tried to read (and it's a known fact that it can be read only once). If used in `Prism::Action`, make sure to call `Prism::Action#copy_body` before.
#
# If you want to implement your own type cast, extend it with `.from_s` method (see `Time.from_s` for example).
#
# If included into `Prism::Action`, will automatically inject `parse_params` into `Action#before` callback:
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
  # An **essential** params definition block.
  #
  # ```
  # params do
  #   param :id, Int32
  # end
  # ```
  macro params(&block)
    REST___PARAMS = [] of NamedTuple

    {{yield}}

    define_params_tuple
    define_parse_params
  end

  private macro define_params_tuple
    alias ParamsTuple = NamedTuple(
      {% for param in REST___PARAMS %}
        "{{param[:name].id}}": {{param[:type].id}}
      {% end %}
    )
  end
end
