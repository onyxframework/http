# 1. Run this example:
#
# crystal examples/server.cr
#
# 2. Go to the browser:
#
# http://localhost:5000/users
# http://localhost:5000/users/1?token=abc

require "../src/rest"

PORT = 5001

struct User
  JSON.mapping({
    id:    Int32,
    name:  String,
    token: String,
  })

  def initialize(@id, @name, @token)
  end
end

USERS = [User.new(1, "Foo", "abc"), User.new(2, "Bar", "xyz")]

# This class will be injected into request when auth handler is called (see below)
class Auth < Rest::Authable
  getter user : User?

  def initialize(@token : String?)
  end

  def auth
    @user = USERS.find(&.token.== @token)
  end
end

auth = Rest::ProcHandler.new do |handler, context|
  if (token = context.request.query_params.to_h["token"]?)
    context.request.auth = Auth.new(token) # This
  end

  handler.call_next(context)
end

# It's a simple action which prints `USERS.to_json` into the response
struct IndexUsers < Rest::Action
  def call
    json(USERS)
  end
end

# This is a more complicated action, but still simple
struct GetUser < Rest::Action
  include Params # Allow to declare params
  include Auth   # Add `auth!` macro and `auth` getter

  auth! # Halt 401 unless authed

  params do
    param :id, Int32    # Require "id" parameter and cast it to Int32
    param :foo, String? # If "foo" parameter is present, cast it to String?
  end

  def call
    # Require the first user being authed, otherwise return "Forbidden"
    # Underlying code will not be called in this case
    halt!(403) unless auth.user == USERS[0]

    user = USERS.find(&.id.== params[:id])
    halt!(404, "User not found") unless user

    # Print JSON represenation of the user (call `#to_json` on it)
    json(user)
  end
end

router = Rest::Router.new do |r|
  r.get "/" do |env|
    env.response.print("Get some Rest!")
  end

  r.get "/users" do |env|
    IndexUsers.call(env)
  end

  r.get "/users/:id" do |env|
    GetUser.call(env)
  end
end

logger = Logger.new(STDOUT)

handlers = [
  Rest::Logger.new(logger),
  auth,
  router,
]

server = Rest::Server.new("localhost", PORT, handlers, logger)
server.listen
