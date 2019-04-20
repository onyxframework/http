require "callbacks"
require "http/server/context"

require "./endpoint/*"
require "./ext/http/server/response/view"

# An encapsulated HTTP endpoint.
#
# You can modify the response as you want as you still have an access to
# the current `context`. However, it's a good practice to split business and
# rendering logic. For this, a endpoint should return a `View` instance or
# call the `#view` method.
#
# Endpoint params can be defined with the `Endpoint.params` macro (param errors have code 400
# for default endpoints and 4000 for `Channel`s).
# Endpoint errors can be defined with the `Endpoint.errors` macro.
#
# Endpoints also include `Callbacks` module, effectively allowing to define
# `.before` and `.after` callbacks, which would be invoked before and after `#call`.
# Read more about callbacks at [https://github.com/vladfaust/callbacks.cr](https://github.com/vladfaust/callbacks.cr).
#
# ```
# struct Endpoints::GetUser
#   include Onyx::HTTP::Endpoint
#
#   params do
#     path do
#       type id : Int32
#     end
#   end
#
#   errors do
#     type UserNotFound(404), id : Int32
#   end
#
#   def call
#     user = find_user(path_params.id)
#     raise UserNotFound.new(path_params.id) unless user
#     return Views::User.new(user)
#   end
# end
#
# Endpoints::GetUser.call(env) # => Views::User instance, if not raised either Params::Error or UserNotFound
# ```
#
# Router example:
#
# ```
# router = Onyx::HTTP::Router.new do |r|
#   r.get "/", Endpoints::GetUser
#   # Equivalent of
#   r.get "/" do |context|
#     view? = Endpoints::GetUser.call(context)
#
#     if view = view?.as?(HTTP::View)
#       context.response.view ||= view
#     end
#   end
# end
# ```
module Onyx::HTTP::Endpoint
  include Callbacks

  # Where all the action takes place.
  abstract def call

  macro included
    def self.call(context)
      instance = new(context)
      instance.with_callbacks { instance.call }
    end
  end

  # The current HTTP::Server context.
  protected getter context : ::HTTP::Server::Context

  def initialize(@context : ::HTTP::Server::Context)
  end

  # Set a *view* for this request. It takes precendence over the return value:
  #
  # ```
  # def call
  #   view(ViewA.new)
  #   view(ViewB.new)
  #   return ViewC.new
  # end
  #
  # # The resulting view is ViewB
  # ```
  def view(view : View)
    context.response.view = view
  end

  # Set HTTP status code.
  #
  # ```
  # def call
  #   status(400)
  # end
  # ```
  protected def status(status : Int32)
    context.response.status_code = status
  end

  # Set HTTP header.
  #
  # ```
  # def call
  #   header("Content-Type", "application/json")
  # end
  # ```
  protected def header(name, value)
    context.response.headers[name] = value
  end

  # Set response status code to *code* and "Location" header to *location*.
  #
  # NOTE: Does **not** interrupt the call.
  #
  # ```
  # def call
  #   redirect("https://google.com")
  #   puts "Will be executed"
  # end
  # ```
  protected def redirect(location : String | URI, code = 302)
    status(code)
    header("Location", location.to_s)
  end
end
