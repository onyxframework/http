module Prism::Params
  # A params validation module.
  #
  # Implemented inline validations (defined as `:validate` option on param):
  #
  # - *size* (`Range | Int32`) - Validate size;
  # - *gte* (`Comparable`) - Check if param value is *g*reater *t*han or *e*qual (`>=`);
  # - *lte* (`Comparable`) - Check if param value is *l*ess *t*han or *e*qual (`<=`);
  # - *gt* (`Comparable`) - Check if param value is *g*reater *t*han (`>`);
  # - *lt* (`Comparable`) - Check if param value is *l*ess *t*han (`<`);
  # - *in* (`Enumerable`) - Validate if param value is included in range or array etc.;
  # - *regex* (`Regex`) - Validate if param value matches regex;
  # - *custom* (`Proc`) - Custom validation, see example below.
  #
  # ```
  # class SimpleAction
  #   include Prism::Params
  #
  #   params do
  #     type name : String, validate: {
  #       size:   (3..32),
  #       regex:  /\w+/,
  #       custom: ->(name : String) {
  #         error!("doesn't meet condition") unless some_condition?(name)
  #       },
  #     }
  #     type age : Int32?, validate: {in: (18..150)}
  #   end
  #
  #   def self.call(context)
  #     params = parse_params(context)
  #   end
  # end
  # ```
  module Validation
    class Error < Exception
    end

    private macro validate(validations, value)
      {% if validations[:size] %}
        case size = {{validations[:size].id}}
        when Int32
          unless {{value}}.size == size
            error!("must have exact size of #{size}")
          end
        when Range
          unless (size).includes?({{value}}.size)
            error!("must have size in range of #{size}")
          end
        end
      {% end %}

      {% if validations[:in] %}
        unless ({{validations[:in]}}).includes?({{value}})
          error!("must be included in {{validations[:in].id}}")
        end
      {% end %}

      {% if validations[:gte] %}
        unless {{value}} >= {{validations[:gte]}}
          error!("must be greater or equal to {{validations[:gte].id}}")
        end
      {% end %}

      {% if validations[:lte] %}
        unless {{value}} <= {{validations[:lte]}}
          error!("must be less or equal to {{validations[:lte].id}}")
        end
      {% end %}

      {% if validations[:gt] %}
        unless {{value}} > {{validations[:gt]}}
          error!("must be greater than {{validations[:gt].id}}")
        end
      {% end %}

      {% if validations[:lt] %}
        unless {{value}} < {{validations[:lt]}}
          error!("must be less than {{validations[:lt].id}}")
        end
      {% end %}

      {% if validations[:regex] %}
        unless {{validations[:regex]}}.match({{value}})
          error!("must match {{validations[:regex].id}}")
        end
      {% end %}

      {% if validations[:custom] %}
        {{validations[:custom].id}}.call({{value}})
      {% end %}
    end

    # Raise `Validation::Error` with *description*.
    macro error!(description)
      raise Error.new({{description}})
    end
  end
end
