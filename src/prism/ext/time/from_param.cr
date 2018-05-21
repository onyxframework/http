struct Time
  # Initialize from *param*.
  #
  # The param value must either represent number of milliseconds elapsed since the Unix epoch or to be `Time`.
  #
  # ```
  # Time.from_param(<@value="1526120573870">) # => 2018-05-12 10:22:53 UTC
  # ```
  def self.from_param(param : Prism::Params::AbstractParam)
    case param.value
    when String
      epoch_ms(param.value.as(String).to_i64)
    when Int
      epoch_ms(param.value.as(Int).to_i64)
    when Time
      param.value
    when JSON::Any
      epoch_ms(param.value.as(JSON::Any).as_i64? || raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}}))
    else
      raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
    end
  end
end
