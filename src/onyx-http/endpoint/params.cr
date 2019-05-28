require "./params/*"

module Onyx::HTTP::Endpoint
  # Define endpoint params. You should call `.path`, `.query`, `.form` and `.json` macros
  # within the block. Once `.params` is called, a `#params` getter would be set on every
  # endpoint initialization. The `#params` variable would have according `#path`, `#query`,
  # `#form` and `#json` getters itself.
  #
  # It is powered by [`HTTP::Params::Serializable`](https://github.com/vladfaust/http-params-serializable),
  # and it can raise `PathParamsError`, `QueryParamsError`, `FormBodyError` or `JSONBodyError`,
  # which all are `HTTP::Error`s with 400 code.
  macro params(&block)
    struct Params
      # This method is used to copy request body if needed.
      protected def copy_io(from : IO, limit = nil) : IO
        to = IO::Memory.new

        if limit
          IO.copy(from, to, limit)
        else
          IO.copy(from, to)
        end

        return to.rewind
      end

      def initialize(request : ::HTTP::Request)
      end

      {% if block.body.is_a?(Expressions) %}
        {% for expression in block.body.expressions %}
          Onyx::HTTP::Endpoint.{{expression}}
        {% end %}
      {% elsif block.body.is_a?(Call) %}
        Onyx::HTTP::Endpoint.{{yield.id}}
      {% else %}
        {% raise "BUG: Unhandled block body type #{block.body.class_name}" %}
      {% end %}
    end

    protected getter params : Params

    def initialize(@context : ::HTTP::Server::Context)
      {% if @type.overrides?(Onyx::HTTP::Endpoint, "initialize") %}
        previous_def
      {% else %}
        super
      {% end %}

      @params = Params.new(@context.request)
    end
  end
end
