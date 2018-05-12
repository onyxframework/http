require "../params"

module Prism
  abstract struct Action
    # Params module for `Prism::Action`. It injects params parsing into `before` callback.
    #
    # Halts with 422 if `Prism::Params::InvalidParamTypeError`, `Prism::Params::ParamNotFoundError` or `Prism::Params::InvalidParamError` raised.
    #
    # ```
    # struct MyAction < Prism::Action
    #   include Params
    #
    #   params do
    #     param :foo, Int32
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
          rescue ex : InvalidParamTypeError | ParamNotFoundError | InvalidParamError
            context.response.status_code = 422
            context.response.print(ex.message)
          end
        end
      end
    end
  end
end
