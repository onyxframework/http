require "onyx-http/ext/http/server/response/error"

require "kilt"
require "exception_page"
require "http/server/handler"

require "../ext/http/server/response/view"
require "../error"

module Onyx::REST
  # HTTP handler which renders content.
  module Renderer
    # A template renderer powered by [Kilt](https://github.com/jeromegn/kilt).
    # If `::HTTP::Server::Response#error` is present, calls a error proc
    # (`.default_error_proc` by default) which beautifully renders the error utilizing
    # the [Exception Page](https://github.com/crystal-loot/exception_page) shard.
    # Otherwise, if `::HTTP::Server::Response#view` is present, calls `View#render` on it
    # (see `View.template`).
    # It updates the `"Content-Type"` header **only** if error of view is present.
    # Should be put after router.
    # Calls the next handler if it's present.
    class Template
      include ::HTTP::Handler

      # A slightly customized [Exception Page](https://github.com/crystal-loot/exception_page).
      class ExceptionPage < ::ExceptionPage
        # Rewrite default style with red accent color and Onyx logo.
        def styles
          ::ExceptionPage::Styles.new(
            accent: "red",
            logo_uri: "data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjYuMzU2bW0iIGhlaWdodD0iNjYuMzUybW0iIHZlcnNpb249IjEuMSIgdmlld0JveD0iMCAwIDY2LjM1NiA2Ni4zNTIiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+DQogPGc+DQogIDxwYXRoIGQ9Im0zOS4yNTUgMjIuNjYyLTE2LjYxIDQuNDUwNCA0LjQ0NjggMTYuNTk2IDE2LjYxLTQuNDUwNHoiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZmlsbD0iIzdiN2I3YiIgZmlsbC1ydWxlPSJldmVub2RkIiBzdHJva2Utd2lkdGg9Ii4yNjQyMSIvPg0KICA8cGF0aCBkPSJtMi4zNTg0IDMwLjgzNmMtMC41NTIyOCAwLjU1MjQ1LTAuODY4MDggMS4yNTY3LTAuOTQ5MzMgMS45NzM5bDM3Ljg0Ni0xMC4xNDgtNS42OTAxLTIxLjIzN2MtMC45NzA1Ny0wLjExODM4LTEuOTgyMSAwLjE5Mjg1LTIuNzMxOCAwLjkzODM3bC0yOC40NzQgMjguNDczeiIgZmlsbD0iIzE5MTkxOSIvPg0KICA8cGF0aCBkPSJtMzMuNTY1IDEuNDI0IDEwLjEzNyAzNy44MzQgMjEuMjM4LTUuNjkwMWMwLjEwOTQyLTAuOTY0OTYtMC4yMDUwNy0xLjk2NzgtMC45NDgyMy0yLjcxMWwtMjguNDg4LTI4LjQ4OGMtMC41NDUyOS0wLjU0NTI5LTEuMjMxLTAuODU4MjktMS45Mzg1LTAuOTQ0NTh6IiBmaWxsPSIjYjNiM2IzIi8+DQogIDxwYXRoIGQ9Im0yNy4wOTEgNDMuNzA4IDUuNjkwMSAyMS4yMzdjMC45Njg4IDAuMTE5NDIgMS45Nzg4LTAuMTg5NTEgMi43Mjg5LTAuOTMxMDZsMjguNDgxLTI4LjQ4IDAuMDAxMS0wLjAwMTFjMC41NTE4LTAuNTUyMTggMC44NjU4Ni0xLjI0ODQgMC45NDcxNC0xLjk2NTJ6IiBmaWxsPSIjMTkxOTE5Ii8+DQogIDxwYXRoIGQ9Im0xLjQwOSAzMi44MWMtMC4xMDY2MiAwLjk2MjM2IDAuMjA4NjkgMS45NjE5IDAuOTQ5NjkgMi43MDI5bDI4LjQ4OCAyOC40ODhjMC41NDQyOSAwLjU0NDI5IDEuMjI4NCAwLjg1NjUyIDEuOTM0NSAwLjk0MzQ4bC0xMC4xMzctMzcuODMzYy0zLjM0OCAwLjg3NDM3LTE2LjAyNyA0LjI3OC0yMS4yMzUgNS42OTgyeiIgZmlsbD0iIzBhMGEwYSIvPg0KIDwvZz4NCiA8Zz4NCiAgPHBhdGggZD0ibTM5LjI1NSAyMi42NjItMTYuNjEgNC40NTA0IDQuNDQ2OCAxNi41OTYgMTYuNjEtNC40NTA0eiIgY2xpcC1ydWxlPSJldmVub2RkIiBmaWxsPSIjN2I3YjdiIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiIHN0cm9rZS13aWR0aD0iLjI2NDIxIi8+DQogIDxwYXRoIGQ9Im0yLjM1ODQgMzAuODM2Yy0wLjU1MjI4IDAuNTUyNDUtMC44NjgwOCAxLjI1NjctMC45NDkzMyAxLjk3MzlsMzcuODQ2LTEwLjE0OC01LjY5MDEtMjEuMjM3Yy0wLjk3MDU3LTAuMTE4MzgtMS45ODIxIDAuMTkyODUtMi43MzE4IDAuOTM4MzdsLTI4LjQ3NCAyOC40NzN6IiBmaWxsPSIjMTkxOTE5Ii8+DQogIDxwYXRoIGQ9Im0zMy41NjUgMS40MjQgMTAuMTM3IDM3LjgzNCAyMS4yMzgtNS42OTAxYzAuMTA5NDItMC45NjQ5Ni0wLjIwNTA3LTEuOTY3OC0wLjk0ODIzLTIuNzExbC0yOC40ODgtMjguNDg4Yy0wLjU0NTI5LTAuNTQ1MjktMS4yMzEtMC44NTgyOS0xLjkzODUtMC45NDQ1OHoiIGZpbGw9IiNiM2IzYjMiLz4NCiAgPHBhdGggZD0ibTI3LjA5MSA0My43MDggNS42OTAxIDIxLjIzN2MwLjk2ODggMC4xMTk0MiAxLjk3ODgtMC4xODk1MSAyLjcyODktMC45MzEwNmwyOC40ODEtMjguNDggMC4wMDExLTAuMDAxMWMwLjU1MTgtMC41NTIxOCAwLjg2NTg2LTEuMjQ4NCAwLjk0NzE0LTEuOTY1MnoiIGZpbGw9IiMxOTE5MTkiLz4NCiAgPHBhdGggZD0ibTEuNDA5IDMyLjgxYy0wLjEwNjYyIDAuOTYyMzYgMC4yMDg2OSAxLjk2MTkgMC45NDk2OSAyLjcwMjlsMjguNDg4IDI4LjQ4OGMwLjU0NDI5IDAuNTQ0MjkgMS4yMjg0IDAuODU2NTIgMS45MzQ1IDAuOTQzNDhsLTEwLjEzNy0zNy44MzNjLTMuMzQ4IDAuODc0MzctMTYuMDI3IDQuMjc4LTIxLjIzNSA1LjY5ODJ6IiBmaWxsPSIjMGEwYTBhIi8+DQogPC9nPg0KPC9zdmc+DQo="
          )
        end
      end

      DEFAULT_CONTENT_TYPE = "text/html; charset=utf-8"

      # Default error proc. Sets the status code to
      # `error.code` if it is a `REST::Error`, 404 if it is
      # `Onyx::HTTP::Router::RouteNotFoundError`, and 500 otherwise.
      # If the error is neither a `REST::Error` nor `Onyx::HTTP::Router::RouteNotFoundError`
      # **and** *verbose* is `true`, then prints the `ExceptionPage` into
      # the response (i.e. detailed error logs).
      # Otherwise prints a minimalistic page with error code and message only.
      def self.default_error_proc(verbose : Bool = true)
        ->(context : ::HTTP::Server::Context, error : Exception) do
          case error
          when REST::Error
            code = error.code
            message = error.message
          when HTTP::Router::RouteNotFoundError
            code = 404
            message = error.message
          else
            code = 500
            message = verbose ? error.message : "Internal server error"
          end

          if context.request.responds_to?(:id)
            request_id = context.request.id?
          end

          context.response.status_code = code

          if error.is_a?(REST::Error) || error.is_a?(HTTP::Router::RouteNotFoundError) || !verbose
            Kilt.embed("#{__DIR__}/template/rest_error.html.ecr", context.response)
          else
            context.response.print ExceptionPage.for_runtime_exception(context, error)
          end

          nil
        end
      end

      # Initialize self with *error_proc* block (`.default_error_proc` by default).
      # The block will be called once `::HTTP::Server::Response#error` is not `nil`.
      def self.new(content_type : String = DEFAULT_CONTENT_TYPE, &error_proc : ::HTTP::Server::Context, Exception ->)
        new(content_type, &error_proc)
      end

      # Initialize self. *verbose* argument is passed to the `.default_error_proc`.
      # So in development you'd want to set *verbose* to `true` and
      # leave the default *error_proc*. And in production you'd want either to set
      # *verbose* to `false` or to pass a custom *error_proc*.
      #
      # ```
      # # Development
      # renderer = Onyx::REST::Renderer::Template.new
      #
      # # Production
      # renderer = Onyx::REST::Renderer::Template.new(verbose: true)
      # # or
      # renderer = Onyx::REST::Renderer::Template.new(error_proc: ->{})
      # ```
      def initialize(
        verbose : Bool = true,
        @content_type : String = DEFAULT_CONTENT_TYPE,
        @error_proc : Proc(::HTTP::Server::Context, Exception, Nil) = self.class.default_error_proc(verbose)
      )
      end

      # :nodoc:
      def call(context)
        if error = context.response.error
          context.response.content_type = @content_type
          @error_proc.call(context, error)
        elsif view = context.response.view
          context.response.content_type = @content_type
          view.render(context.response)
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
