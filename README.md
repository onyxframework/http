<a href="https://onyxframework.org"><img align="right" width="147" height="147" src="https://onyxframework.org/img/logo.svg"></a>

# Onyx::REST

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![Travis CI build](https://img.shields.io/travis/onyxframework/rest/master.svg?style=flat-square)](https://travis-ci.org/onyxframework/rest)
[![API docs](https://img.shields.io/badge/api_docs-online-brightgreen.svg?style=flat-square)](https://api.onyxframework.org/rest)
[![Latest release](https://img.shields.io/github/release/onyxframework/rest.svg?style=flat-square)](https://github.com/onyxframework/rest/releases)

A REST API framework for [Crystal](https://crystal-lang.org).

## About

Onyx::REST is an opinionated REST API framework — basically, a collection of HTTP handlers and the default [HTTP::Server](https://crystal-lang.org/api/HTTP/Server.html) wrapper. It's thoroughly designed to be as much beginner-friendly as possible, yet scale with the developer's knowledge of the [Crystal Language](https://crystal-lang.org). The framework itself is [SOLID](https://en.wikipedia.org/wiki/SOLID) (excluding some simplifications to reduce boilerplate code), modular (there can be multiple servers in one application and there are no top-level macros by default) and respects configuration over convention.

### Benchmarks

[![Benchmarks](https://d3ugvbs94d921r.cloudfront.net/5c273d8b3ba0f6ef7c65d832.svg?t=b938d2bf4965222&v=3318a7b2)](https://public.chartblocks.com/c/5c273d8b3ba0f6ef7c65d832?t=b938d2bf4965222)

*Source: [https://github.com/the-benchmarker/web-frameworks@2dc801850d6cfed91333cf9af87f7b2c363d9e38](https://github.com/the-benchmarker/web-frameworks/blob/2dc801850d6cfed91333cf9af87f7b2c363d9e38/README.md)*

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  onyx-rest:
    github: onyxframework/rest
    version: ~> 0.5.0
```

This shard follows [Semantic Versioning v2.0.0](http://semver.org/), so check [releases](https://github.com/onyxframework/rest/releases) and change the `version` accordingly. Please visit [github.com/crystal-lang/shards](https://github.com/crystal-lang/shards) to know more about Crystal shards.

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
INFO [14:04:34.082] ⬛ Onyx::REST::Server is shutting down!
```

```console
$ curl http://localhost:5000
Hello Onyx!
```

### Handlers

Fundamentally, every Onyx::REST application is a stack of HTTP handlers passed to the [Onyx::REST::Server](https://api.onyxframework.org/rest/Onyx/REST/Server.html). To add new functionality, you add new handlers to the stack. There is a number of implemented handlers which fit the most common REST application needs:

* [Onyx::REST::Router](https://api.onyxframework.org/rest/Onyx/REST/Router.html) — routes the request to a proc
* [Onyx::REST::CORS](https://api.onyxframework.org/rest/Onyx/REST/CORS.html) — Cross Origin Resource Sharing handler
* [Onyx::REST::RequestID](https://api.onyxframework.org/rest/Onyx/REST/RequestID.html) — adds ID to the request
* Rescuers — rescue unhandled errors
  * [Onyx::REST::Rescuers::Standard](https://api.onyxframework.org/rest/Onyx/REST/Rescuers/Standard.html) — rescues errors and logs them colorfully to a standard Crystal logger
* Loggers — log requests
  * [Onyx::REST::Loggers::Standard](https://api.onyxframework.org/rest/Onyx/REST/Loggers/Standard.html) — logs requests colorfully to a standard Crystal logger
* Renderers — render responses
  * [Onyx::REST::Renderers::JSON](https://api.onyxframework.org/rest/Onyx/REST/Renderers/JSON.html) — renders to JSON

#### Request ID

The built-in [Onyx::REST::RequestID](https://api.onyxframework.org/rest/Onyx/REST/RequestID.html) adds a random UUID to the [Request instance](https://api.onyxframework.org/rest/HTTP/Request.html):

```crystal
request_id = Onyx::REST::RequestID.new
handlers = [request_id, router]
server = Onyx::REST::Server.new(handlers)
# ditto
```

```console
$ curl http://127.0.0.1:5000
X-Request-ID: 23bac83d-4894-4e6c-b007-7785ff73d684
```

#### Logging requests

Built-in requests logger is pretty easy to use:

```crystal
logger = Onyx::REST::Loggers::Standard.new
handlers = [request_id, logger, rescuer]
# ditto
```

```console
INFO [14:04:32.578] [4821be8e]      GET / 200 127μs
INFO [14:04:36.718] [6ec8d538]     POST /users 201 1.579ms
INFO [14:04:39.912] [60c5d1ed]      GET /unknown 404 77μs
```

#### Rescuing unhandled errors

If an unhandled error raised somewhere during processing the request, the Crystal process doesn't crash and the user sees `500 Internal Server Error`, but the error's backtrace is put directly into `STDERR` and the handlers stack is exited. Therefore, it's a good idea to add a rescuer handler into the stack. For example, default [Onyx::REST::Rescuers::Standard](https://api.onyxframework.org/rest/Onyx/REST/Rescuers/Standard.html) logs the error into a standard Crystal logger:

```crystal
router.get "/error" do |env|
  raise "Oops"
end

rescuer = Onyx::REST::Rescuers::Standard.new
handlers = [request_id, logger, rescuer, router]
```

```console
INFO [14:04:32.578] [8e0c113f]  ERROR  Oops

Oops (Exception)
  from spec/json_server.cr:23:9 in '->'
  from src/onyx-rest/router.cr:255:3 in '->'
  from src/onyx-rest/router.cr:255:3 in 'call'
  from /usr/share/crystal/src/http/server/handler.cr:24:7 in 'call_next'
  from src/onyx-rest/rescuer.cr:20:5 in 'call'
  from /usr/share/crystal/src/http/server/handler.cr:24:7 in 'call_next'
  from src/onyx-rest/rescuer.cr:20:5 in 'call'
  from /usr/share/crystal/src/http/server/handler.cr:24:7 in 'call_next'
  from src/onyx-rest/loggers/standard.cr:73:11 in 'call'

INFO [14:04:32.578] [8e0c113f]     GET /error 500 1.890ms
```

You can also specify the "next" handler for a rescuer, so it calls it directly upon rescuing:

```crystal
renderer = Onyx::REST::Renderers::JSON.new
rescuer = Onyx::REST::Rescuers::Standard.new(renderer)
# ditto
```

And the result would be:

```json
{
  "error": {
    "class": "UnhandledServerError",
    "message": "Unhandled server error. If you are the application owner, see the logs for details",
    "code": 500
  }
}
```

### REST errors

There is a [`Onyx::REST::Error`](https://api.onyxframework.org/rest/Onyx/REST/Error.html) abstract class which defines an **expected** error, for example:

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

These errors are typically rescued by the router and renderers (no need for a [Rescuer](https://api.onyxframework.org/rest/Onyx/REST/Rescuer.html) in this case):

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

# Standard rescuers rescues `Exception`s
rescuer = Onyx::REST::Rescuers::Standard.new

# Params rescuer rescues only Params errors and skips other `Exception`s
params_rescuer = HTTP::Params::Serializable::Rescuer.new

server = Onyx::REST::Server.new([rescuer, params_rescuer, router])
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

This software is licensed under [BSD 3-Clause License](LICENSE).

[![Open Source Initiative](https://upload.wikimedia.org/wikipedia/commons/thumb/4/42/Opensource.svg/100px-Opensource.svg.png)](https://opensource.org/licenses/BSD-3-Clause)
