module Prism::Params
  # Define a single param. Must be called within the `#params` block.
  #
  # **Arguments:**
  #
  # - *name* declares an access key for the `params` tuple
  # - *type* defines a type which the param must be casted to, otherwise validation will fail (i.e. "foo" won't cast to `Int32`)
  # - *:nilable* option declares if this param is nilable (the same effect is achieved with nilable *type*, i.e. `Int32?`)
  # - *validate* option accepts a `Proc` which must return truthy value for the param to pass validation
  #
  # NOTE: If a param is nilable, but is present and of invalid type, an `InvalidParamTypeError` will be raised.
  #
  # ```
  # params do
  #   param :id, Int32, validate: ->(id : Int32) { id > 0 }
  #   param :name, String?             # => Nilable
  #   param :age, Int32, nilable: true # => Nilable as well
  # end
  # ```
  macro param(name, type _type, **options)
    {%
      nilable = if options[:nilable] == nil
                  "#{_type}".includes?("?") || "#{_type}".includes?("Nil")
                else
                  options[:nilable]
                end

      INTERNAL__PRISM_PARAMS.push({
        name:       name,
        type:       _type,
        nilable:    nilable,
        validation: options[:validate],
      })
    %}
  end
end
