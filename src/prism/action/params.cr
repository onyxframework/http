require "../params"

module Prism
  module Action
    # Params module for `Prism::Action`. It injects params parsing into `before` callback.
    #
    # Halts with 422 if `Prism::Params::InvalidParamTypeError`, `Prism::Params::ParamNotFoundError` or `Prism::Params::InvalidParamError` raised.
    #
    # ```
    # struct MyAction
    #   include Prism::Action
    #   include Prism::Action::Params
    #
    #   params do
    #     type foo : Int32
    #   end
    #
    #   def call
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
            @params = self.class.parse_params(context, self.class.max_body_size)
          rescue ex : InvalidParamTypeError | ParamNotFoundError | InvalidParamError | ProcError
            context.response.status_code = 422
            context.response.print(ex.message)
          end
        end
      end
    end
  end
end
