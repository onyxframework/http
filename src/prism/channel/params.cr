require "../params"

module Prism
  class Channel
    # Params module for `Prism::Channel`. It injects params parsing into `before` callback.
    #
    # Closes the socket if `Prism::Params::InvalidParamTypeError`, `Prism::Params::ParamNotFoundError` or `Prism::Params::InvalidParamError` raised.
    #
    # ```
    # class MyChannel < Prism::Channel
    #   include Params
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
          rescue ex : InvalidParamTypeError | ParamNotFoundError | InvalidParamError
            socket.close(ex.message)
            false
          end
        end
      end
    end
  end
end
