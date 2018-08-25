struct Bool
  # Initialize from *param*.
  #
  # The param value must be either `true`, `"true"`, `false` or `"false"`.
  #
  # ```
  # Bool.from_param(<@value="true">) # => true
  # ```
  def self.from_param(param : Prism::Params::AbstractParam)
    case param.value
    when true, "true"   then true
    when false, "false" then false
    else                     raise Prism::Params::InvalidParamTypeError.new(param, "Bool")
    end
  end
end
