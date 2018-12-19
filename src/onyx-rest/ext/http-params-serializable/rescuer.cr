require "http-params-serializable"
require "../../rescuer"
require "../http/server/response/error"
require "./onyx/rest/errors/params_error"

# An `Onyx::REST::Rescuer` which takes care of `HTTP::Params::Serializable` errors.
# It sets `HTTP::Context::Response#error` to the error instance before handler call,
# otherwise it prints the `"400 <Original error message>"` into the response body.
class HTTP::Params::Serializable::Rescuer < Onyx::REST::Rescuer(HTTP::Params::Serializable::Error)
  def process(context : HTTP::Server::Context, error : HTTP::Params::Serializable::Error)
    # Do nothing
  end

  def before_handler(context : HTTP::Server::Context, error : HTTP::Params::Serializable::Error)
    context.response.error = Onyx::REST::Errors::ParamsError.new(error.message.not_nil!, error.path)
  end

  def fallback(context : HTTP::Server::Context, error : HTTP::Params::Serializable::Error)
    context.response.respond_with_error(error.message, 400)
  end
end
