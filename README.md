# ⚛️ Atom::Web

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![Build status](https://img.shields.io/travis/atomframework/web/master.svg?style=flat-square)](https://travis-ci.org/atomframework/web)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg?style=flat-square)](https://atomframework.github.io/web/)
[![Releases](https://img.shields.io/github/release/atomframework/web.svg?style=flat-square)](https://github.com/atomframework/web/releases)
[![Awesome](https://github.com/vladfaust/awesome/blob/badge-flat-alternative/media/badge-flat-alternative.svg)](https://github.com/veelenga/awesome-crystal)
[![vladfaust.com](https://img.shields.io/badge/style-.com-lightgrey.svg?longCache=true&style=flat-square&label=vladfaust&colorB=0a83d8)](https://vladfaust.com)
[![Patrons count](https://img.shields.io/badge/dynamic/json.svg?label=patrons&url=https://www.patreon.com/api/user/11296360&query=$.included[0].attributes.patron_count&style=flat-square&colorB=red&maxAge=86400)](https://www.patreon.com/vladfaust)

A collection of HTTP components for building Action-View-oriented frameworks. Used in [Atom Framework](https://github.com/atomframework/atom).

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

* [Action](https://atomframework.github.io/web/Atom/Web/Action.html) - ensapsulates logic
* [View](https://atomframework.github.io/web/Atom/Web/View.html) - responsible for rendering
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
  * [Simple JSON API example](#simple-json-api-example)
  * [Websockets](#websockets-example)

### Without [Atom](https://github.com/atomframework/atom)

[Atom](https://github.com/atomframework/atom) reduces overall code by wrapping common scenarios into macros, so the code below is quite verbose.

#### Basic example

```crystal
require "atom-web"

record User, id : Int32, name : String

Users = {1 => User.new(1, "John")}

struct Actions::GetUser
  include Atom::Action

  params do
    type id : Int32
  end

  errors do
    type UserNotFound(404)
  end

  def call
    user = Users[params.id]? || raise UserNotFound.new
    return Views::User.new(user)
  end
end

struct Views::User
  include Atom::View

  def initialize(@user : ::User)
  end

  def to_s(io)
    io << "id: #{@user.id}, name: #{@user.name}\n"
  end
end

logger = Logger.new(STDOUT, Logger::DEBUG)
request_logger = Atom::Handlers::RequestLogger.new(logger)

router = Atom::Handlers::Router.new do
  get "/users/:id", Actions::GetUser
end

server = HTTP::Server.new([request_logger, router]) do |context|
  if proc = context.proc
    proc.call(context)

    if error = context.response.error
      case error
      when Params::Error
        code = 400
        message = error.message
      when Atom::Action::Error
        code = error.code
        message = error.class.name
      else
        code = 500
        message = error.message
      end

      context.response.respond_with_error(message, code)
    elsif view = context.response.view
      context.response.print(view)
    end
  else
    context.response.respond_with_error("Route Not Found: #{context.request.path}", 404)
  end
end

server.bind_tcp(5000)
logger.info("Listening at http://#{server.addresses.first}")
server.listen

# I,  INFO -- : Listening at http://127.0.0.1:5000
# D, DEBUG -- :     GET /users/1 200 139μs
# D, DEBUG -- :     GET /users/2 404 197μs
# D, DEBUG -- :     GET /users/foo 400 623μs
# D, DEBUG -- :     GET /user 404 111μs
```

```shell
$ curl http://127.0.0.1:5000/users/1
id: 1, name: John
$ curl http://127.0.0.1:5000/users/2
404 Actions::GetUser::UserNotFound
$ curl http://127.0.0.1:5000/users/foo
400 Couldn't cast parameter `id` from `String` to `Int32`
$ curl http://127.0.0.1:5000/user
404 Route Not Found: /user
```

#### Simple JSON API example

In this example, an application always returns formatted JSON responses.

```crystal
require "atom-web"

record User, id : Int32, name : String

Users = {1 => User.new(1, "John")}

struct Actions::GetUser
  include Atom::Action

  params do
    type id : Int32
  end

  errors do
    type UserNotFound(404), id : Int32 do
      super "User not found with id #{id}"
    end
  end

  def call
    user = Users[params.id]? || raise UserNotFound.new(params.id)
    return Views::User.new(user)
  end
end

struct Views::User
  include Atom::View

  def initialize(@user : ::User)
  end

  def to_json(json)
    {id: @user.id, name: @user.name}.to_json(json)
  end
end

router = Atom::Handlers::Router.new do
  get "/users/:id", Actions::GetUser
end

server = HTTP::Server.new([router]) do |context|
  if proc = context.proc
    proc.call(context)

    if context.response.error || context.response.view
      json = JSON::Builder.new(context.response.output)
      context.response.content_type = "application/json"

      json.document do
        if error = context.response.error
          message = error.message
          payload = nil

          case error
          when Params::TypeCastError
            code = 400
            payload = {parameter: error.pretty_path, expectedType: error.target, actualType: error.source}
          when Params::MissingError
            code = 400
            payload = {parameter: error.pretty_path}
          when Params::Error
            code = 400
          when Atom::Action::Error
            code = error.code
            payload = error.payload
          else code = 500
          end

          context.response.status_code = code

          {
            success: false,
            error:   {
              name:    error.class.name.split("::").last,
              message: message,
              payload: payload,
            },
          }.to_json(json)
        elsif view = context.response.view
          {
            success: true,
            data:    view,
          }.to_json(json)
        end
      end
    end
  else
    json = JSON::Builder.new(context.response.output)
    context.response.content_type = "application/json"
    context.response.status_code = 404

    json.document do
      {
        success: false,
        error:   {
          name:    "RouteNotFound",
          message: "Route not found: #{context.request.path}",
          payload: {
            path: context.request.path,
          },
        },
      }.to_json(json)
    end
  end
end

server.bind_tcp(5000)
puts "Listening at http://#{server.addresses.first}"
server.listen
```

```shell
$ curl http://127.0.0.1:5000/users/1
{"success":true,"data":{"id":1,"name":"John"}}
$ curl http://127.0.0.1:5000/users/2
{"success":false,"error":{"name":"UserNotFound","message":"User not found with id 2","payload":{"id":2}}}
$ curl http://127.0.0.1:5000/users/foo
{"success":false,"error":{"name":"TypeCastError","message":"Couldn't cast parameter `id` from `String` to `Int32`","payload":{"parameter":"id","expectedType":"Int32","actualType":"String"}}}
$ curl http://127.0.0.1:5000/user
{"success":false,"error":{"name":"RouteNotFound","message":"Route not found: /user","payload":{"path":"/user"}}}
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
