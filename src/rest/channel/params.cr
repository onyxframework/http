require "../params"

module Rest
  class Channel
    # Params module for `Channel`. Closes the socket on validation error.
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
              true
            rescue ex : InvalidParamTypeError | ParamNotFoundError | InvalidParamError
              socket.close(ex.message)
              false
            end
          end
        end
      end
    end
  end
end
