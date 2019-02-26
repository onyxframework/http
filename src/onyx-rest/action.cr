require "callbacks"

require "./action/*"
require "./endpoint"

require "./ext/http/server/response/view"

# A callable REST action.
#
# An Action itself isn't responsible for rendering. It *should* return a `View` instance or
# explicitly set `HTTP::Server::Response#view` to a `View` instance with the `#view` method,
# and that view *should* be rendered in future handlers.
#
# Action includes the `Endpoint` module.
# Action params can be defined with the `Endpoint.params` macro (param errors have code 400).
# Action errors can be defined with the `Endpoint.errors` macro.
#
# Action includes `Callbacks` module, effectively allowing to define `.before` and `.after` callbacks,
# which would be invoked before and after `#call`. Read more about callbacks at [https://github.com/vladfaust/callbacks.cr](https://github.com/vladfaust/callbacks.cr).
#
# ```
# struct Actions::GetUser
#   include Onyx::REST::Action
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
# Actions::GetUser.call(env) # => Views::User instance, if not raised either Params::Error or UserNotFound
# ```
#
# Router example:
#
# ```
# router = Onyx::HTTP::Router.new do
#   get "/", Actions::GetUser
#   # Equivalent of
#   get "/" do |context|
#     view? = Actions::GetUser.call(context)
#
#     if view = view?.as?(REST::View)
#       context.response.view ||= view
#     end
#   end
# end
# ```
module Onyx::REST::Action
  include Endpoint
  include Callbacks

  PARAMS_ERROR_CODE = 400

  # Where all the action takes place.
  abstract def call

  macro included
    def self.call(context)
      instance = new(context)
      instance.with_callbacks { instance.call }
    end
  end

  # Set a *view* for this request. In router, the first view assigned takes precendence:
  #
  # ```
  # def call
  #   view(ViewA.new)
  #   return ViewB.new
  # end
  #
  # # The resulting view is ViewA
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
  # Does **not** interrupt the call.
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
