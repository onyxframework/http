require "../params"

module Rest
  struct Action
    module Params
      include Rest::Params

      macro params(&block)
        Rest::Params.params do
          {{yield}}
        end

        @params = uninitialized ParamsTuple
        protected getter params

        def before
          if previous_def
            begin
              @params = self.class.parse_params(context)
            rescue ex : InvalidParamTypeError | ParamNotFoundError
              context.response.status_code = 400
              context.response.print(ex.message)
            end
          end
        end
      end
    end
  end
end
