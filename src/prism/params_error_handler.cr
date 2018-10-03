require "http/server/handler"
require "params"

module Prism
  # `HTTP::Handler` which catches [Params](https://github.com/vladfaust/params.cr) errors
  # (e.g. when param is missing or failed to cast).
  #
  # It's explicit because different APIs (JSON or text) may want to handle these errors differently.
  #
  # It's also different from standard
  # [HTTP::ErrorHandler](https://crystal-lang.org/api/latest/HTTP/ErrorHandler.html)
  # because Params errors are considered normal.
  #
  # ```
  # handler = Prism::ParamsErrorHandler.new do |error, context|
  #   context.response.status = 400
  #   context.response.print(error.message)
  # end
  # ```
  class ParamsErrorHandler
    include HTTP::Handler

    @proc : Proc(::Params::Error, HTTP::Server::Context, Void)

    def initialize(&@proc : ::Params::Error, HTTP::Server::Context -> _)
    end

    def call(context)
      begin
        call_next(context)
      rescue ex : ::Params::Error
        @proc.call(ex, context)
      end
    end
  end
end
