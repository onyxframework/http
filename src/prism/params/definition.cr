module Prism::Params
  # Define a single param or nested params. Must be called within the `#params` block.
  #
  # Params must be defined with standard Crystal variable definition syntax, which is underscore (e.g. `array_param`). Upon parsing, *under_score*, *kebab-case* and *lowerCamelcase* keys are considered valid. Thus said, incoming params can include either `"array_param"`, `"array-param"` or `"arrayParam"` key.
  #
  # NOTE: However, only key the same as the param's name (`"array_param"`) is valid when casting from *path params*.
  #
  # Example:
  #
  # ```
  # params do
  #   type user do
  #     type email : String, validate: {regex: /@/}
  #     type password : String, validate: {size: (0..32)}
  #     type age : Int32?
  #     type about_me : String? # about_me, about-me and aboutMe keys are looked up upon parsing
  #   end
  # end
  # ```
  #
  # **Nested params** (e.g. `type user do`) can have following options:
  #
  # - *nilable* (`false` by default, change as `type user, nilable: true do`).
  #
  # **Single param** has two mandatory arguments:
  #
  # - *name* declares an access key for the `params` tuple;
  # - *type* defines a type which the param must be casted to, otherwise validation will fail (i.e. "foo" won't cast to `Int32`). You can declary an arbitary type, union or array (e.g. `Array(UInt16)`), must it respond to `.from_param`. See `Int.from_param` and its siblings for implementations.
  #
  # NOTE: Union Array type isn't supported, e.g. `type foo : Array(Int32 | String)` is invalid because of uncertainty of how to process it, for example `["42"]` - should `"42"` stay String or be casted to Int32?
  #
  # **Single param** can also have some options:
  #
  # - *nilable* declares if this param is nilable (the same effect is achieved with nilable *type*, i.e. `Int32?`);
  # - *validate* defines validation options. See `Validation`;
  #
  # NOTE: If a param is nilable, but is present and of invalid type, an `InvalidParamTypeError` will be raised.
  macro type(declaration, **options, &block)
    {% if block %}
      {%
        INTERNAL__PRISM_PARAMS_PARENTS[:current_value].push(declaration.id.stringify)

        if options[:nilable]
          INTERNAL__PRISM_PARAMS_PARENTS[:nilable][INTERNAL__PRISM_PARAMS_PARENTS[:current_value].select { |x| x }.map(&.id.stringify)] = options[:nilable]
        end
      %}

      {{yield}}

      \{%
        current_size = INTERNAL__PRISM_PARAMS_PARENTS[:current_value].select{ |x| x }.size
        INTERNAL__PRISM_PARAMS_PARENTS[:current_value][current_size - 1] = nil
        INTERNAL__PRISM_PARAMS_PARENTS[:current_value] = INTERNAL__PRISM_PARAMS_PARENTS[:current_value].select{ |x| x }
      %}
    {% else %}
      {%
        nilable = if options[:nilable] == nil
                    if declaration.type.is_a?(Union)
                      declaration.type.types.map(&.stringify).includes?("::Nil")
                    else
                      false
                    end
                  else
                    options[:nilable]
                  end

        array = if declaration.type.is_a?(Union)
                  declaration.type.types.any? { |t| t.stringify == "Array" } || (
                    declaration.type.is_a?(Union) && declaration.type.types.first.is_a?(Generic) && declaration.type.types.first.name.stringify == "Array"
                  )
                elsif declaration.type.is_a?(Generic)
                  declaration.type.name.stringify == "Array"
                else
                  false
                end

        INTERNAL__PRISM_PARAMS.push({
          parents: INTERNAL__PRISM_PARAMS_PARENTS[:current_value].size > 0 ? INTERNAL__PRISM_PARAMS_PARENTS[:current_value].map { |x| x.id.stringify } : nil,
          name:     declaration.var.stringify,
          keys:     [declaration.var.stringify, declaration.var.stringify.underscore, declaration.var.stringify.underscore.gsub(/_/, "-"), declaration.var.stringify.camelcase[0...1].downcase + declaration.var.stringify.camelcase[1..-1]].uniq,
          type: declaration.type,
          nilable: nilable,
          validate: options[:validate],
          array: array,
        })
      %}
    {% end %}
  end

  # TODO: Introduce macro recursion
  private macro define_params_tuple
    {%
      tuple_hash = INTERNAL__PRISM_PARAMS.reduce({} of Object => Object) do |hash, param|
        if !param[:parents]
          hash[param[:name]] = param[:type]
        else
          if param[:parents].size == 0
            hash[param[:name]] = param[:type]
          elsif param[:parents].size == 1
            key = param[:parents][0]
            hash[key] = {} of Object => Object unless hash[key]
            hash[key]["__nilable"] = true if INTERNAL__PRISM_PARAMS_PARENTS[:nilable][param[:parents]]

            hash[key][param[:name]] = param[:type]
          elsif param[:parents].size == 2
            key = param[:parents][0]
            hash[key] = {} of Object => Object unless hash[key]

            key1 = param[:parents][1]
            hash[key][key1] = {} of Object => Object unless hash[key][key1]
            hash[key][key1]["__nilable"] = true if INTERNAL__PRISM_PARAMS_PARENTS[:nilable][param[:parents]]

            hash[key][key1][param[:name]] = param[:type]
          elsif param[:parents].size == 3
            key = param[:parents][0]
            hash[key] = {} of Object => Object unless hash[key]

            key1 = param[:parents][1]
            hash[key][key1] = {} of Object => Object unless hash[key][key1]

            key2 = param[:parents][2]
            hash[key][key1][key2] = {} of Object => Object unless hash[key][key1][key2]
            hash[key][key1][key2]["__nilable"] = true if INTERNAL__PRISM_PARAMS_PARENTS[:nilable][param[:parents]]

            hash[key][key1][key2][param[:name].id.stringify] = param[:type]
          else
            raise "Too deep params nesting"
          end
        end

        hash
      end

      raise "Empty params" if tuple_hash.empty?
    %}

    # Damn hacks
    alias ParamsTuple = NamedTuple({{"#{tuple_hash}".gsub(/\"/, "\"").gsub(%r[=> {(.*), "__nilable" => true(.*)}[,}]], "=> {\\1\\2} | Nil,").gsub(%r[=> {(.*)"__nilable" => true, (.*)}[,}]], "=> {\\1\\2} | Nil,").gsub(/ \=>/, ":")[1..-2].id}})
  end

  private macro define_param_type
    struct Param < AbstractParam
      alias Type = {{INTERNAL__PRISM_PARAMS.map(&.[:type]).join(" | ").id}} | String | Hash(String, Param) | Array(String) | JSON::Any | Null | Nil
      getter value : Type
    end
  end
end
