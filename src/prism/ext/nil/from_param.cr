struct Nil
  def self.from_param(param : Prism::Params::AbstractParam)
    unless param.value == nil
      raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
    end
  end
end
