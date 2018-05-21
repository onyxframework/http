module Prism::Params
  # Define a single param or nested params. Must be called within the `#params` block.
  #
  # Example:
  #
  # ```
  # params do
  #   param :user do
  #     param :email, String, validate: {regex: /@/}
  #     param :password, String, validate: {size: (0..32)}
  #     param :age, Int32?
  #   end
  # end
  # ```
  #
  # **Nested params** (e.g. `param :user do`) can have following options:
  #
  # - *nilable* (`false` by default).
  #
  # **Single param** has two mandatory arguments:
  #
  # - *name* declares an access key for the `params` tuple;
  # - *type* defines a type which the param must be casted to, otherwise validation will fail (i.e. "foo" won't cast to `Int32`). You can declary an arbitary type, union or array (e.g. `Array(UInt16)`), must it respond to `.from_param`. See `Int.from_param` and its siblings for implementations.
  #
  # NOTE: Union Array type isn't supported, e.g. `param :foo, Array(Int32 | String)` is invalid because of uncertainty of how to process it, for example `["42"]` - should `"42"` stay String or be casted to Int32?
  #
  # **Single param** can also have some options:
  #
  # - *nilable* declares if this param is nilable (the same effect is achieved with nilable *type*, i.e. `Int32?`);
  # - *validate* defines validation options. See `Validation`;
  # - *proc* will be called each time the param is casted (right after validation). The param becomes the returned value, so this *proc* **must** return the same type.
  #
  # NOTE: If a param is nilable, but is present and of invalid type, an `InvalidParamTypeError` will be raised.
  macro param(name, type _type = nil, **options, &block)
    {% if block %}
      {%
        INTERNAL__PRISM_PARAMS_PARENTS[:current_value].push(name)

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
        raise "Expected param type" unless _type

        nilable = if options[:nilable] == nil
                    "#{_type}".includes?("?") || "#{_type}".includes?("Nil")
                  else
                    options[:nilable]
                  end

        array = if _type.is_a?(Generic)
                  "#{_type.name}" =~ /Array$/ || (
                    "#{_type.name}" =~ /Union$/ && _type.type_vars.first.is_a?(Generic) && "#{_type.type_vars.first.name}" =~ /Array$/
                  )
                else
                  false
                end

        INTERNAL__PRISM_PARAMS.push({
          parents: INTERNAL__PRISM_PARAMS_PARENTS[:current_value].size > 0 ? INTERNAL__PRISM_PARAMS_PARENTS[:current_value].map { |x| x.id.stringify } : nil,
          name: name.id.stringify,
          type: _type,
          nilable: nilable,
          validate: options[:validate],
          proc: options[:proc],
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
    %}

    # Damn hacks
    alias ParamsTuple = NamedTuple({{"#{hash}".gsub(/\"/, "\"").gsub(%r[=> {(.*), "__nilable" => true(.*)}[,}]], "=> {\\1\\2} | Nil ").gsub(%r[=> {(.*)"__nilable" => true, (.*)}[,}]], "=> {\\1\\2} | Nil ").gsub(/ \=>/, ":")[1..-2].id}})
  end

  private macro define_param_type
    struct Param < AbstractParam
      alias Type = {{INTERNAL__PRISM_PARAMS.map(&.[:type]).join(" | ").id}} | String | Hash(String, Param) | Array(String) | JSON::Any | Nil
      getter value : Type
    end
  end
end
