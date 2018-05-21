class Array(T)
  # Initialize from *param* value which must be an Array itself.
  #
  # If the Array type is Union, the type order matters. See `Union.from_param`:
  #
  # ```
  # param = <@value=["foo", 42]>
  #
  # Array(UInt16 | String).from_param(param) == ["foo", 42_u16]
  # # but
  # Array(String | UInt16).from_param(param) == ["foo", "42"]
  # ```
  def self.from_param(param : Prism::Params::AbstractParam)
    case param.value
    when self
      param.value
    when Array(String)
      param.value.as(Array).map do |e|
        T.from_param(Prism::Params::StringParam.new(param.name, e.as(String), param.path))
      end.as(self)
    when JSON::Any
      begin
        param.value.as(JSON::Any).as_a.map do |e|
          T.from_param(Prism::Params::JSONParam.new(param.name, e, param.path))
        end
      rescue TypeCastError
        raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
      end
    else
      raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
    end
  end
end
