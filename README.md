<img src="https://user-images.githubusercontent.com/7955682/34129522-75a7bd5c-e455-11e7-9d64-d207b35c24d0.png" width="256">

Prism is a tiny but powerful Crystal web framework.

[![Build Status](https://travis-ci.org/vladfaust/prism.svg?branch=master)](https://travis-ci.org/vladfaust/prism) [![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://vladfaust.com/prism) [![Dependencies](https://shards.rocks/badge/github/vladfaust/prism/status.svg)](https://shards.rocks/github/vladfaust/prism) [![GitHub release](https://img.shields.io/github/release/vladfaust/prism.svg)](https://github.com/vladfaust/prism/releases)

## Why

- Because I believe that a singleton *configuration* for an applicaiton is anti-pattern, e.g. what if you want multiple HTTP servers in one process?
- Because I want *simple* params validation and typecasting.
- Because I don't want many shards for Restful *essentials* like CORS and authorization.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  prism:
    github: vladfaust/prism
```

This shard follows [Semantic Versioning v2.0.0](http://semver.org/).

## Usage

Please refer to the documentation available online at [vladfaust.com/prism](https://vladfaust.com/prism).

### Basic example

```crystal
require "prism"

struct GetUser < Prism::Action
  include Params # Allow to declare params

  params do
    param :id, Int32 # Require "id" parameter and cast it to Int32
  end

  def call
    user = User.find(id: params[:id])
    halt!(404, "User not found") unless user

    # Print JSON represenation of the user (call `#to_json` on it)
    json(user)
  end
end

router = Prism::Router.new do |r|
  r.get "/" do |env|
    env.response.print("Hello world!")
  end

  r.get "/users/:id" do |env|
    GetUser.call(env)
  end

  r.on "/users/:id", methods: %w(post put) do |env|
    env.response.print("Will update user #{env.request.path_params["id"]}")
  end
end

handlers = [
  Prism::Logger.new(logger),
  router,
]

server = Prism::Server.new("localhost", 5000, handlers, logger)
server.listen

#  INFO -- :    Prism server vX.Y.Z is listening on http://localhost:5000
```

### Auth

`Prism::Authable`, `Prism::ProcHandler` and `Prism::Action::Auth` allow to define authentication logic in no time!

```crystal
class Auth < Prism::Authable
  @user : User? = nil
  getter! user

  def initialize(@token : String)
  end

  # This method will be lazily called on `auth!`
  def auth
    @user = find_user_by_token(@token)
  end
end

struct SecureAction < Prism::Action
  include Auth

  auth! # Halt 401 unless authorized

  def call
    # Basically, `auth` wraps `context.request.auth.not_nil!` in this case
    json(auth.user) # Yep, just like that
  end
end

# Add this handler to handlers list before or after router
auth = Prism::ProcHandler.new do |handler, context|
  if (token = context.request.query_params.to_h["token"]?)
    context.request.auth = Auth.new(token) # This
  end
  handler.call_next(context)
end
```

A soft auth could be applied as well, just do not do `auth!`; in this case, you'll need to call `auth?` then, which is a shortcut to `context.request.auth.try &.auth`.

### Websockets ⚡️

Easy peazy:

```crystal
require "prism/channel"

class Notifications < Prism::Channel
  @@subscriptions = Array(self).new # It's a custom code

  # It's a custom code as well
  def self.notify(message)
    @@subscriptions.each do |sub|
      sub.socket.send(message)
    end
  end

  def on_open
    socket.send("Hola")
    @@subscriptions.push(self)
  end

  def on_close
    @@subscriptions.delete(self)
  end
end

router = Prism::Router.new do |r|
  r.ws "/notifications" do |socket, env|
    Notifications.subscribe(socket, env)
  end
end

# Later in the code...

Notifications.notify("A message") # How do you like that?!
```

## Contributing

1. Fork it ( https://github.com/vladfaust/prism/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
