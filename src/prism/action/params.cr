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

      macro included
        @@preserve_body = false

        # Call to preserve body upon params parsing.
        #
        # Without `preserve_body`:
        #
        # ```
        # struct Action
        #   include Prism::Action::Params
        #
        #   def call
        #     body # Will be empty after parsing params from form or JSON
        #   end
        # end
        # ```
        #
        # With `preserve_body`:
        #
        # ```
        # struct Action
        #   include Prism::Action::Params
        #
        #   preserve_body
        #
        #   def call
        #     body # Will return String even after body read while params parsing
        #   end
        # end
        # ```
        def self.preserve_body
          @@preserve_body = true
        end
      end

      macro params(&block)
        Prism::Params.params do
          {{yield}}
        end

        @params = uninitialized ParamsTuple
        protected getter params

        before do
          begin
            @params = self.class.parse_params(context, self.class.max_body_size, @@preserve_body)
          rescue ex : InvalidParamTypeError | ParamNotFoundError | InvalidParamError | ProcError
            context.response.status_code = 422
            context.response.print(ex.message)
          end
        end
      end
    end
  end
end
