struct Union(T)
  # Initialize from *param* value.
  #
  # `.from_param` casting is attempted on each union type unless found suitable.
  #
  # NOTE: Types are iterated alphabetically, so `UInt8 | Null` would turn to `Null | UInt8`. That's why `Int32 | String` won't work, it will always return `String`.
  def self.from_param(param : Prism::Params::AbstractParam)
    result = (
      {% for t in T %}
        begin
          return {{ t.id }}.from_param(param).as(self)
        rescue Prism::Params::InvalidParamTypeError | ArgumentError
        end
      {% end %}
    )

    raise Prism::Params::InvalidParamTypeError.new(param, {{@type.id.stringify}})
  end
end
