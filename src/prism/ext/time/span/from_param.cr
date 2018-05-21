struct Time::Span
  # Initialize from *param*.
  #
  # The param value must either represent a number of nanoseconds (1 billionth of second) or to be `Time::Span` itself.
  #
  # ```
  # Time::Span.from_param(<@value="500">) # => 00:00:00.000000500
  # ```
  def self.from_param(param : Prism::Params::AbstractParam)
    case param.value
    when String
      new(nanoseconds: param.value.as(String).to_i64)
    when Int
      new(nanoseconds: param.value.as(Int).to_i64)
    when Time::Span
      param.value
    when JSON::Any
      new(nanoseconds: param.value.as_i64? || raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}}))
    else
      raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
    end
  end
end
