# Onyx::REST

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![Travis CI build](https://img.shields.io/travis/com/onyxframework/rest/master.svg?style=flat-square)](https://travis-ci.com/onyxframework/rest)
[![API docs](https://img.shields.io/badge/api_docs-online-brightgreen.svg?style=flat-square)](https://api.onyxframework.org/rest)
[![Latest release](https://img.shields.io/github/release/onyxframework/rest.svg?style=flat-square)](https://github.com/onyxframework/rest/releases)

A REST API framework [Crystal](https://crystal-lang.org).

## About

Onyx::REST is an opinionated REST API framework — basically, a collection of HTTP handlers and a default HTTP::Server wrapper. It's thoroughly designed to be as much beginner-friendly as possible, yet scale with the developer's knowledge of the [Crystal Language](https://crystal-lang.org). The framework itself is modular and respects configuration over convention.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  onyx-rest:
    github: onyxframework/rest
    version: ~> 0.5.0
```

This shard follows [Semantic Versioning v2.0.0](http://semver.org/), so check [releases](https://github.com/onyxframework/rest/releases) and change the `version` accordingly.

## Usage

This is the most basic example of an application written with Onyx::REST:

```crystal
require "onyx-rest"

router = Onyx::REST::Router.new do
  get "/" do
    "Hello Onyx!"
  end
end

server = Onyx::REST::Server.new(router)
server.bind_tcp(5000)
server.listen
```

```console
 INFO [14:04:31.493] ⬛ Onyx::REST::Server is listening at http://127.0.0.1:5000
 INFO [14:04:32.578]      GET / 200 127μs
 INFO [14:04:34.082] ⬛ Onyx::REST::Server is shutting down!
```

```console
$ curl http://localhost:5000
Hello Onyx!
$
```

### Handlers

Fundamentally, every Onyx::REST application is a stack of HTTP handlers. To add new functionality, you add new handlers to the stack. There is a number of implemented handlers which fit the most common REST application needs:

* [Onyx::REST::Router](https://api.onyxframework.org/rest/Onyx/REST/Router.html) — routes the request to a proc
* [Onyx::REST::CORS](https://api.onyxframework.org/rest/Onyx/REST/CORS.html) — Cross Origin Resource Sharing handler
* [Onyx::REST::RequestID](https://api.onyxframework.org/rest/Onyx/REST/RequestID.html) — adds ID to the request
* Rescuers — rescue unhandled errors
  * [Onyx::REST::Rescuers::Standard](https://api.onyxframework.org/rest/Onyx/REST/Rescuers/Standard.html) — rescue errors and log to a standard Crystal logger
* Loggers — log requests
  * [Onyx::REST::Loggers::Standard](https://api.onyxframework.org/rest/Onyx/REST/Loggers/Standard.html) — log to a standard Crystal logger
* Renderers — render responses
  * [Onyx::REST::Renderers::JSON](https://api.onyxframework.org/rest/Onyx/REST/Renderers/JSON.html) — render to JSON

### REST error

There is a `Onyx::REST::Error` abstract class which defines an **expected** error, for example:

```crystal
class UserNotFound < Onyx::REST::Error(404)
  def initialize(id)
    super("User not found with id #{id}")
  end
end

router.get "/users/:id" do |env|
  id = env.request.path_params["id"].to_i?
  raise UserNotFound.new(id) unless Models::User.find(id)
end
```

You can then add a [`Rescuer`](https://api.onyxframework.org/rest/Onyx/REST/Rescuer.html) to the stack, for example [`Onyx::REST::Rescuers::Standard`](https://api.onyxframework.org/rest/Onyx/REST/Rescuers/Standard.html):

```crystal
handlers << Onyx::REST::Rescuers::Standard.new
```

```console
$ curl http://localhost:5000/users/42
404 User not found with id 42
```

### Params

Onyx::REST has a built-in rescuer for [`HTTP::Params::Serializable`](https://github.com/vladfaust/http-params-serializable), which makes defining typed params a piece of cake:

```crystal
require "onyx-rest"
require "onyx-rest/ext/http-params-serializable"

struct FindUserParams
  include HTTP::Params::Serializable

  getter name : String
  getter age : Int32
end

router.get "/users" do |env|
  params = FindUserParams.new(env.request.query)
  users = Models::Users.find(name: params.name, age: params.age)

  if user = users[0]?
    "#{user.first_name} #{user.last_name}"
  end
end

handlers << HTTP::Params::Serializable::Rescuer.new
```

```console
$ curl http://localhost:5000/users?age=foo
400 Parameter "age" can't be cast from "foo" to Int32
$ curl http://localhost:5000/users?age=22
Vlad Faust
```

## Contributing

1. Fork it ( https://github.com/onyxframework/rest/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [Vlad Faust](https://github.com/vladfaust) - creator and maintainer

## Licensing

This software is licensed under BSD 3-Clause License with "Commons Clause" License Condition v1.0. See [LICENSE](LICENSE).
