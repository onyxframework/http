# ⚛️ Atom::Web

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![Build status](https://img.shields.io/travis/atomframework/web/master.svg?style=flat-square)](https://travis-ci.org/atomframework/web)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg?style=flat-square)](https://atomframework.github.io/web/)
[![Releases](https://img.shields.io/github/release/atomframework/web.svg?style=flat-square)](https://github.com/atomframework/web/releases)
[![Awesome](https://github.com/vladfaust/awesome/blob/badge-flat-alternative/media/badge-flat-alternative.svg)](https://github.com/veelenga/awesome-crystal)
[![vladfaust.com](https://img.shields.io/badge/style-.com-lightgrey.svg?longCache=true&style=flat-square&label=vladfaust&colorB=0a83d8)](https://vladfaust.com)
[![Patrons count](https://img.shields.io/badge/dynamic/json.svg?label=patrons&url=https://www.patreon.com/api/user/11296360&query=$.included[0].attributes.patron_count&style=flat-square&colorB=red&maxAge=86400)](https://www.patreon.com/vladfaust)

A collection of HTTP components used in [Atom Framework](https://github.com/atomframework/atom).

[![Become Patron](https://vladfaust.com/img/patreon-small.svg)](https://www.patreon.com/vladfaust)

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  atom-web:
    github: atomframework/web
    version: ~> 0.5.0
```

This shard follows [Semantic Versioning v2.0.0](http://semver.org/), so check [releases](https://github.com/atomframework/web/releases) and change the `version` accordingly.

## Included components

* [Action](https://atomframework.github.io/web/Atom/Web/Action.html) - ensapsulates logic and rendering
* [Channel](https://atomframework.github.io/web/Atom/Web/Channel.html) - convenient websockets wrapper
* Handlers
  * [CORS](https://atomframework.github.io/web/Atom/Web/Handlers/CORS.html) - handles [CORS](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing)
  * [Proc](https://atomframework.github.io/web/Atom/Web/Handlers/Proc.html) - calls a proc on each call
  * [RequestLogger](https://atomframework.github.io/web/Atom/Web/Handlers/RequestLogger.html) - colorfully logs requests
  * [Rescuer](https://atomframework.github.io/web/Atom/Web/Handlers/Rescuer.html) - rescues errors
  * [Router](https://atomframework.github.io/web/Atom/Web/Handlers/Router.html) - routes requests

## Usage

* [Without Atom](#without-atom)
  * [Basic example](#basic-example)
  * [Custom JSON renderer](#custom-json-renderer-example)
  * [Websockets](#websockets-example)

### Without [Atom](https://github.com/atomframework/atom)

[Atom](https://github.com/atomframework/atom) reduces overall code by wrapping common scenarios into macros, so the code below is quite verbose.

#### Basic example

```crystal
require "atom-web"

struct KnockKnock
  include Atom::Action

  params do
    type who : String
    type how_many : Int32
  end

  def call
    how_many.times do
      text("Knock-knock #{who}\n")
    end
  end
end

logger = Logger.new(STDOUT, Logger::DEBUG)
request_logger = Atom::Handlers::RequestLogger.new(logger)

router = Atom::Handlers::Router.new do
  get "/:who", KnockKnock
end

server = HTTP::Server.new([request_logger, router]) do |context|
  if proc = context.proc
    proc.call(context)
  else
    context.response.respond_with_error("Not Found: #{context.request.path}", 404)
  end
rescue ex : Params::Error
  context.response.respond_with_error(ex.message, 400)
end

server.bind_tcp(5000)
logger.info("Listening at http://#{server.addresses.first}")

server.listen

# DEBUG -- :     GET /me 200 177μs
```

```
curl -X GET -d "howMany=2" http://127.0.0.1:5000/me
Knock-knock me
Knock-knock me
```

#### Custom JSON renderer example

In this example, an application always returns formatted JSON responses.

```crystal
require "atom-web"

record User, id : Int32, name : String

Users = {1 => User.new(1, "John")}

module CustomRenderer
  def render(value)
    success = (200..299) === context.response.status_code

    json = JSON::Builder.new(context.response.output)
    json.document do
      json.object do
        json.field("success", success)
        json.field(success ? "data" : "error") do
          value.to_json(json)
        end
        json.field("status", context.response.status_code)
      end
    end

    context.response.content_type = "application/json; charset=utf-8"
  end
end

struct Actions::GetUser
  include Atom::Action
  include CustomRenderer

  params do
    type id : Int32
  end

  def call
    if user = Users[id]?
      render(Views::User.new(user))
    else
      halt(404, "User not found with id #{id}")
    end
  end
end

struct Views::User
  def initialize(@user : ::User)
  end

  def to_json(json)
    json.object do
      json.field("id", @user.id)
      json.field("name", @user.name)
    end
  end
end

request_logger = Atom::Handlers::RequestLogger.new(Logger.new(STDOUT, Logger::DEBUG))

router = Atom::Handlers::Router.new do
  get "/users/:id", Actions::GetUser
end

server = HTTP::Server.new([request_logger, router]) do |context|
  if proc = context.proc
    proc.call(context)
  else
    context.response.respond_with_error("Not Found: #{context.request.path}", 404)
  end
rescue ex : Params::Error
  context.response.respond_with_error(ex.message, 400)
end

server.bind_tcp(5000)
puts "Listening at http://#{server.addresses.first}"
server.listen
```

#### Websockets example

We call them *Channels* for convenience.

```crystal
require "atom-web"

class Notifications
  include Atom::Channel

  @@subscriptions = Array(self).new

  def self.notify(message)
    @@subscriptions.each &.socket.send(message)
  end

  def on_open
    socket.send("Hello")
    @@subscriptions.push(self)
  end

  def on_close
    @@subscriptions.delete(self)
  end
end

router = Atom::Handlers::Router.new do
  ws "/notifications" do |socket, env|
    Notifications.subscribe(socket, env)
  end
end

# Later in the code...

Notifications.notify("Something happened!") # Will notify all subscribers binded to this particular Crystal process
```

## Contributing

1. Fork it ( https://github.com/atomframework/web/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
