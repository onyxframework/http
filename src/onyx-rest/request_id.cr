require "uuid"
require "http/server/handler"
require "./ext/http/request/id"

# Sets `HTTP::Request#id` and `"X-Request-ID"` header to a random `UUID` string.
# If a request has an ID, it's printed upon logging in
# `Onyx::REST::Loggers::Standard` and `Onyx::REST::Rescuers::Standard` handlers.
class Onyx::REST::RequestID
  include HTTP::Handler

  def call(context)
    id = UUID.random.to_s
    context.request.id = id
    context.response.headers["X-Request-ID"] = id
    call_next(context)
  end
end
