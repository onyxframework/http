# Rest

Rest (*noun*) is a modular web framework. ¯\\_(ツ)_/¯

> Take some Rest!

[![Build Status](https://travis-ci.org/vladfaust/rest.cr.svg?branch=master)](https://travis-ci.org/vladfaust/rest.cr) [![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://vladfaust.com/rest.cr) [![Dependencies](https://shards.rocks/badge/github/vladfaust/rest.cr/status.svg)](https://shards.rocks/github/vladfaust/rest.cr) [![GitHub release](https://img.shields.io/github/release/vladfaust/rest.cr.svg)](https://github.com/vladfaust/rest.cr/releases)

## Why

- Because I love modularity and hate Singletons.
- Because I want simple params validation and typecasting.
- Because I don't want many shards for Restful essentials like CORS and authorization.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  rest:
    github: vladfaust/rest.cr
```

This shard follows [Semantic Versioning v2.0.0](http://semver.org/).

## Usage

Please refer to the documentation available online @ [vladfaust.com/rest.cr](https://vladfaust.com/rest.cr).

Remember that the most of the components can be used separately.

```crystal
require "rest"

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

server = Rest::Server.new("localhost", 5000, handlers, logger)
server.listen

#  INFO -- :   Rest server v0.1.0 is up @ http://localhost:5000
#  INFO -- :    GET /? 200 61μs
#  INFO -- :    GET /users? 200 139μs
#  INFO -- :    GET /users/1? 401 94μs
#  INFO -- :    GET /users/1?token=abc 200 169μs
#  INFO -- :   Rest server is going to take some rest ~(˘▾˘~)
```

## Contributing

1. Fork it ( https://github.com/vladfaust/rest.cr/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
