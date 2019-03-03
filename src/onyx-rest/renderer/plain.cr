require "onyx-http/ext/http/server/response/error"

require "http/server/handler"

require "../ext/http/server/response/view"
require "../error"

module Onyx::REST
  # HTTP handler which renders content.
  module Renderer
    # A plain text renderer. If `::HTTP::Server::Response#error` is present, prints it,
    # otherwise renders `::HTTP::Server::Response#view`, calling `View#to_s` on it.
    # It updates the `"Content-Type"` header **only** if error of view is present.
    # Should be put after router.
    # Calls the next handler if it's present.
    class Plain
      include ::HTTP::Handler

      CONTENT_TYPE = "text/plain; charset=utf-8"

      # Initialize self.
      # If *verbose* is `true`, puts the actual error message into the response,
      # otherwise puts "Internal Server Error".
      def initialize(@verbose : Bool = true)
      end

      # :nodoc:
      def call(context)
        if error = context.response.error
          context.response.content_type = CONTENT_TYPE

          case error
          when REST::Error
            code = error.code
            message = error.message
          when ::HTTP::Params::Serializable::Error
            code = 400
            message = error.message
          when HTTP::Router::RouteNotFoundError
            code = 404
            message = error.message
          else
            code = 500
            message = @verbose ? error.message : "Internal Server Error"
          end

          context.response.status_code = code
          context.response << code << " " << message
        elsif view = context.response.view
          context.response.content_type = CONTENT_TYPE
          view.to_plain_text(context.response)
        end

        if self.next
          call_next(context)
        else
          context.response.error = nil
          context.response.view = nil
        end
      end
    end
  end
end
