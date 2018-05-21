class String
  # Initialize from *param*. It basically returns `param.value.as(String)`.
  #
  # ```
  # String.from_param(<@value="foo">) # => "foo"
  # ```
  def self.from_param(param : Prism::Params::AbstractParam)
    case param.value
    when JSON::Any
      param.value.as(JSON::Any).as_s? || raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
    else
      param.value.as(String)
    end
  end
end
