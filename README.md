<img src="https://user-images.githubusercontent.com/7955682/34129522-75a7bd5c-e455-11e7-9d64-d207b35c24d0.png" width="256">

Prism is an expressive modular web framework.

[![Build Status](https://travis-ci.org/vladfaust/prism.svg?branch=master)](https://travis-ci.org/vladfaust/prism) [![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://vladfaust.com/prism) [![Dependencies](https://shards.rocks/badge/github/vladfaust/prism/status.svg)](https://shards.rocks/github/vladfaust/prism) [![GitHub release](https://img.shields.io/github/release/vladfaust/prism.svg)](https://github.com/vladfaust/prism/releases)

## Why

- Because *modular* approach is better than singleton configurations.
- Because params need *easy* validation and typecasting.
- Because *essentials* like CORS and authorization should be in one place.

## Contents

1. [Installation](#installation)
2. [Usage](#usage)
   1. [Basic example with params](#basic-example-with-params)
   2. [Auth](#auth)
   3. [⚡️ Websockets](#websockets)

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

### Basic example with params

```crystal
require "logger"
require "prism"

struct GetUser < Prism::Action
  include Params # Enable params in this action

  params do
    param :id, Int32, validate: ->(i : Int32) { i > 0 } # Require "id" parameter and cast it to Int32
    param :display_info, Bool? # This parameter is optional
  end

  def call
    typeof(params[:id]) # => Int32
    typeof(params[:display_info]) # => Bool?

    user = User.where(id: params[:id])
    halt!(404, "User not found") unless user # Will abort further execution

    user.info = "blah" if params[:display_info]

    # Print JSON represenation of the user (call `#to_json` on it)
    json(user)
  end
end

router = Prism::Router.new do |r|
  r.get "/" do |env|
    env.response.print("Hello world!") # Simple
  end

  r.get "/users/:id" do |env|
    GetUser.call(env) # Action call, :id will be casted to Int32 param (see above)
  end

  r.on "/users/:id", methods: %w(post put) do |env|
    typeof(env.request.path_params) # => Hash(String, String), no typecasting
    env.response.print("Will update user #{env.request.path_params["id"]}")
  end
end

logger = Logger.new(STDOUT)

server = Prism::Server.new("localhost", 5000, [Prism::Logger.new(logger), router], logger)
server.listen

#  INFO -- :   Prism server v0.1.0 is listening on http://localhost:5000...
```

### Auth

`Prism::Authable`, `Prism::ProcHandler` together allow to define authentication logic in no time!

```crystal
class Auth < Prism::Authable
  @user : User? = nil
  getter! user

  def initialize(@token : String)
  end

  # This method will be lazily called on `auth!` (see below)
  def auth
    @user = find_user_by_token(@token)
  end
end

struct StrictAction < Prism::Action
  include Auth # Enable auth in this action

  auth! # Halt 401 unless authorized

  def call
    # Basically, `auth.user` equals to `context.request.auth.not_nil!.user` (see below)
    json(auth.user) # Yep, just like that
  end
end

struct ConditionalAction < Prism::Action
  include Auth

  def call
    if auth?
      json(auth.user)
    else
      text("Hey, you're not authed")
    end
  end
end

# Add this handler to handlers list before or after router
# Will extract token from "?token=xyz" query param
auth = Prism::ProcHandler.new do |handler, context|
  if (token = context.request.query_params.to_h["token"]?)
    context.request.auth = Auth.new(token) # No magic, just science
  end

  handler.call_next(context)
end
```

### Websockets

We call them Channels for convenience.

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

  # This is one of the default callbacks
  def on_open
    socket.send("Hola")
    @@subscriptions.push(self)
  end

  # ditto
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

Notifications.notify("A message") # Will notify all subscribers
```

Remember that websockets are bound to this particular Crystal process only!

## Contributing

1. Fork it ( https://github.com/vladfaust/prism/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
