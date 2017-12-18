require "../params"

module Prism
  class Channel
    # Params module for `Channel`. Closes the socket on validation error.
    module Params
      include Prism::Params

      macro params(&block)
        Prism::Params.params do
          {{yield}}
        end

        @params = uninitialized ParamsTuple
        protected getter params

        before do
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
