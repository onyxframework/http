# A special object stating that the value is not empty but intentionally null.
#
# For example, params in PATCH action can be `Null` to unset a model's properties:
#
# ```
# params do
#   type email : String | Null?, validate: {regex: /@/} # Validations will be run on String only
# end
#
# def call
#   case params[:email]
#   when String then user.email = params[:email]
#   when Null   then user.email = nil
#   end
# end
# ```
#
# To mark parameter as a Null, a "null" string must be passed, e.g. `"?email=null"`. However, when parsing from JSON, explicit `null` fields would be turned into Null, and `"null"` would not:
#
# ```
# {email: null}   # params[:email] === Null
# {email: "null"} # params[:email] === String
# ```
struct Null
  # Initialize from *param* value.
  #
  # Will return self instance if current param value equals to `"null"` (doesn't work for JSON):
  #
  # ```
  # Null.from_param(<@value="null">) # => Null()
  # Null.from_param(<@value=42>)     # raise Prism::Params::InvalidParamTypeError
  # ```
  def self.from_param(param : Prism::Params::AbstractParam)
    return self.new if param.value.is_a?(Null) || param.value == "null" || param.value == "NULL"
    raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
  end

  # Raises an exception.
  #
  # See also: `Object#not_nil!`.
  def not_nil!
    raise "Nil assertion failed (is Null)"
  end
end
