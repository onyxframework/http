require "../params"

module Prism
  module Channel
    # Params module for `Prism::Channel`. It injects params parsing into `before` callback.
    #
    # Closes the socket if `Prism::Params::InvalidParamTypeError`, `Prism::Params::ParamNotFoundError` or `Prism::Params::InvalidParamError` raised.
    #
    # ```
    # class MyChannel
    #   include Prism::Channel
    #   include Prism::Channel::Params
    #
    #   params do
    #     param :foo, Int32
    #   end
    #
    #   def on_open
    #     params[:foo] # => Int32
    #   end
    # end
    # ```
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
          rescue ex : InvalidParamTypeError | ParamNotFoundError | InvalidParamError | ProcError
            socket.close(ex.message)
            false
          end
        end
      end
    end
  end
end
