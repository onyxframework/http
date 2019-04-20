require "exception_page"

require "../ext/http/server/response/view"
require "../ext/http/server/response/error"
require "../ext/exception/status_message"
require "../error"

module Onyx::HTTP::Middleware
  # A handler which renders either `context.response.error` or `context.response.view` if
  # it is present. Errors rendering is determined by the `"Accept"` request header and can
  # be either `"application/json"`, `"text/plain"` (*default*) or `"text/html"`.
  class Renderer
    include ::HTTP::Handler

    class ExceptionPage < ::ExceptionPage
      def styles
        ::ExceptionPage::Styles.new(
          accent: "red",
        )
      end
    end

    # You are likely to set *verbose* to `false` in production mode to
    # hide actual error payloads.
    def initialize(@verbose : Bool = true)
    end

    def call(context)
      if error = context.response.error
        if context.response.upgraded?
          return (call_next(context) if self.next)
        else
          if accept = context.request.accept
            rendered = false

            accept.each do |a|
              case a.media_type
              when "text/html"
                render_html_error(context, error)
                break rendered = true
              when "application/json"
                render_json_error(context, error)
                break rendered = true
              when "text/plain", "*/*"
                render_text_error(context, error)
                break rendered = true
              end
            end

            unless rendered
              render_text_error(context, error)
            end
          else
            render_text_error(context, error)
          end
        end
      elsif view = context.response.view
        view.render(context)
      end

      if self.next
        call_next(context)
      end
    end

    # Render `Onyx::HTTP::Error` into JSON. Example:
    #
    # ```json
    # {
    #   "error": {
    #     "name": "User Not Found",
    #     "message": "User not found with ID 42",
    #     "code": 404,
    #     "payload": {
    #       "id": 42
    #     }
    #   }
    # }
    # ```
    def render_json_error(context, error : Error)
      context.response.content_type = "application/json"
      context.response.status_code = error.code

      {
        error: {
          name:    error.status_message,
          message: error.message,
          code:    error.code,
          payload: error.payload,
        },
      }.to_json(context.response)
    end

    # Render an exception into JSON. Based on the `@verbosity` variable, the output differs.
    #
    # Example with `@verbose = true`:
    #
    # ```json
    # {
    #   "error": {
    #     "name": "Division By Zero",
    #     "message": "Division by zero",
    #     "code": 500,
    #     "payload": {
    #       "backtrace": ["<error_backtrace>"]
    #     }
    #   }
    # }
    # ```
    #
    # With `@verbose = false`:
    #
    # ```json
    # {
    #   "error": {
    #     "name": "Exception",
    #     "message": null,
    #     "code": 500,
    #     "payload": null
    #   }
    # }
    # ```
    def render_json_error(context, error : Exception)
      context.response.content_type = "application/json"
      context.response.status_code = 500

      if @verbose
        {
          error: {
            name:    error.status_message,
            message: error.message,
            code:    500,
            payload: {
              backtrace: error.backtrace,
            },
          },
        }.to_json(context.response)
      else
        {
          error: {
            name:    ::HTTP::Status.new(500).description,
            message: nil,
            code:    500,
            payload: nil,
          },
        }.to_json(context.response)
      end
    end

    # Render an `Onyx::HTTP::Error` into a minimalistic HTML page.
    # It uses [Kilt](https://github.com/jeromegn/kilt) under the hood.
    def render_html_error(context, error : Error)
      context.response.content_type = "text/html"
      context.response.status_code = error.code

      Kilt.embed("#{__DIR__}/renderer/rest_error.html.ecr", context.response)
    end

    # Render an exception into HTML.
    # It uses [Kilt](https://github.com/jeromegn/kilt) under the hood.
    # Based on the `@verbose` variable, the output differs.
    # If it is `true`, then a debug page is output powered by [ExceptionPage](https://github.com/crystal-loot/exception_page) shard.
    # Otherwise, a minimalistic HTML page is rendered with no details.
    def render_html_error(context, error : Exception)
      context.response.content_type = "text/html"
      context.response.status_code = 500

      if @verbose
        context.response.print ExceptionPage.for_runtime_exception(context, error)
      else
        Kilt.embed("#{__DIR__}/renderer/rest_error.html.ecr", context.response)
      end
    end

    # Render an `Onyx::HTTP::Error` into a plain text.
    # If the error contains a message, it is print with dash:
    #
    # ```
    # 404 User Not Found — User not found with ID 42
    # ```
    def render_text_error(context, error : Error)
      context.response.content_type = "text/plain"
      context.response.status_code = error.code

      context.response << error.code << " " << error.status_message

      if message = error.message
        context.response << " — " << message
      end
    end

    # Render an exception into a plain text.
    # The output differs depending on the `@verbose` variable.
    # If it is set to `true`, then a full error message with backtrace is printed.
    # Otherwise, a simple `500 Internal Server Error` message is printed.
    def render_text_error(context, error : Exception)
      context.response.content_type = "text/plain"
      context.response.status_code = 500

      if @verbose
        context.response << "500 " << error.status_message
        context.response << " — " << error.message << "\n\n" << error.backtrace.join("\n")
      else
        context.response << "500 " << ::HTTP::Status.new(500).description
      end
    end
  end
end
