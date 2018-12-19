require "json"
require "http/server/handler"
require "../ext/http/server/response"
require "../error"

class Onyx::REST
  # HTTP handlers which render content.
  module Renderers
    # A JSON renderer. If `HTTP::Context::Response#error` is present, prints it as a JSON object.
    # Otherwise, if `HTTP::Context::Response#text` is present, prints it as is.
    # Calls the next handler if it's present.
    class JSON
      include HTTP::Handler

      def call(context)
        if (error = context.response.error) || (text = context.response.text)
          context.response.content_type = "application/json; charset=utf-8"

          if error
            json = ::JSON::Builder.new(context.response.output)
            json.document do
              json.object do
                json.field("error") do
                  name = "UnhandledServerError"
                  message = "Unhandled server error. If you are the application owner, see the logs for details"
                  code = 500
                  payload = nil

                  if error.is_a?(REST::Error)
                    code = error.code
                    name = error.name
                    message = error.message
                    payload = error.payload
                  end

                  context.response.status_code = code

                  json.object do
                    json.field "class", name || error.class.name.split("::").last
                    json.field "message", message if message && !message.empty?
                    json.field "code", code
                    json.field "payload", payload if payload
                  end
                end
              end
            end
          elsif text
            context.response.output << text
          else
            raise "BUG: neither error nor text"
          end

          context.response.output << "\n"
        end

        if self.next
          call_next(context)
        end
      end
    end
  end
end
