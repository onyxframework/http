<a href="https://onyxframework.org"><img width="100" height="100" src="https://onyxframework.org/img/logo.svg"></a>

# Onyx::HTTP

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![Travis CI build](https://img.shields.io/travis/onyxframework/http/master.svg?style=flat-square)](https://travis-ci.org/onyxframework/http)
[![Docs](https://img.shields.io/badge/docs-online-brightgreen.svg?style=flat-square)](https://docs.onyxframework.org/http)
[![API docs](https://img.shields.io/badge/api_docs-online-brightgreen.svg?style=flat-square)](https://api.onyxframework.org/http)
[![Latest release](https://img.shields.io/github/release/onyxframework/http.svg?style=flat-square)](https://github.com/onyxframework/http/releases)

An opinionated framework for scalable web.

## About 👋

Onyx::HTTP is an opinionated HTTP framework for [Crystal language](https://crystal-lang.org/). It features DSL and modules to build modern, scalabale web applications with first-class support for websockets.

## Installation 📥

Add these lines to your application's `shard.yml`:

```yaml
dependencies:
  onyx:
    github: onyxframework/onyx
    version: ~> 0.6.0
  onyx-http:
    github: onyxframework/http
    version: ~> 0.9.0
```

This shard follows [Semantic Versioning v2.0.0](http://semver.org/), so check [releases](https://github.com/onyxframework/http/releases) and change the `version` accordingly.

> Note that until Crystal is officially released, this shard would be in beta state (`0.*.*`), with every **minor** release considered breaking. For example, `0.1.0` → `0.2.0` is breaking and `0.1.0` → `0.1.1` is not.

## Usage 💻

The simplest hello world:

```crystal
require "onyx/http"

Onyx::HTTP.get "/" do |env|
  env.response << "Hello, world!"
end

Onyx::HTTP.listen
```

Encapsulated endpoints:

```crystal
struct GetUser
  include Onyx::HTTP::Endpoint

  params do
    path do
      type id : Int32
    end
  end

  errors do
    type UserNotFound(404)
  end

  def call
    user = Onyx::SQL.query(User.where(id: params.path.id)).first? # This code is part of onyx/sql
    raise UserNotFound.new unless user

    return UserView.new(user)
  end
end

Onyx::HTTP.get "/users/:id", GetUser
```

Encapsulated views:

```crystal
struct UserView
  include Onyx::HTTP::View

  def initialize(@user : User)
  end

  json id: @user.id, name: @user.name
end
```

Websocket channels:

```crystal
struct Echo
  include Onyx::HTTP::Channel

  def on_message(message)
    socket.send(message)
  end
end

Onyx::HTTP.ws "/", Echo
```

## Documentation 📚

The documentation is available online at [docs.onyxframework.org/http](https://docs.onyxframework.org/http).

## Community 🍪

There are multiple places to talk about Onyx:

* [Gitter](https://gitter.im/onyxframework)
* [Twitter](https://twitter.com/onyxframework)

## Support ❤️

This shard is maintained by me, [Vlad Faust](https://vladfaust.com), a passionate developer with years of programming and product experience. I love creating Open-Source and I want to be able to work full-time on Open-Source projects.

I will do my best to answer your questions in the free communication channels above, but if you want prioritized support, then please consider becoming my patron. Your issues will be labeled with your patronage status, and if you have a sponsor tier, then you and your team be able to communicate with me privately in [Twist](https://twist.com). There are other perks to consider, so please, don't hesistate to check my Patreon page:

<a href="https://www.patreon.com/vladfaust"><img height="50" src="https://onyxframework.org/img/patreon-button.svg"></a>

You could also help me a lot if you leave a star to this GitHub repository and spread the word about Crystal and Onyx! 📣

## Contributing

1. Fork it ( https://github.com/onyxframework/http/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'feat: some feature') using [Angular style commits](https://github.com/angular/angular/blob/master/CONTRIBUTING.md#commit)
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [Vlad Faust](https://github.com/vladfaust) - creator and maintainer

## Licensing

This software is licensed under [MIT License](LICENSE).

[![Open Source Initiative](https://upload.wikimedia.org/wikipedia/commons/thumb/4/42/Opensource.svg/100px-Opensource.svg.png)](https://opensource.org/licenses/MIT)
