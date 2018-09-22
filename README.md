# ![Prism](https://user-images.githubusercontent.com/7955682/40576015-3d691524-60f8-11e8-8b6a-3d17c3bd11e6.png)

[![Built with Crystal](https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square)](https://crystal-lang.org/)
[![Build status](https://img.shields.io/travis/vladfaust/prism/master.svg?style=flat-square)](https://travis-ci.org/vladfaust/prism)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg?style=flat-square)](https://github.vladfaust.com/prism)
[![Releases](https://img.shields.io/github/release/vladfaust/prism.svg?style=flat-square)](https://github.com/vladfaust/prism/releases)
[![Awesome](https://github.com/vladfaust/awesome/blob/badge-flat-alternative/media/badge-flat-alternative.svg)](https://github.com/veelenga/awesome-crystal)
[![vladfaust.com](https://img.shields.io/badge/style-.com-lightgrey.svg?longCache=true&style=flat-square&label=vladfaust&colorB=0a83d8)](https://vladfaust.com)

Prism is an expressive web framework with a speed of light. Features:

- ⚡️ **Efficiency** based on [Crystal](https://crystal-lang.org) performance
- ✨ **Expressiveness** with powerful DSL and lesser code
- 💼 **Safety** with strictly typed params

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  prism:
    github: vladfaust/prism
    version: ~> 0.4.0
```

This shard follows [Semantic Versioning v2.0.0](http://semver.org/), so check [releases](https://github.com/vladfaust/prism/releases) and change the `version` accordingly.

## Basic example

Please refer to the API documentation available online at [github.vladfaust.com/prism](https://github.vladfaust.com/prism).

```crystal
require "prism"

struct KnockKnock
  include Prism::Action
  include Prism::Action::Params

  params do
    type who : String
    type how_many_times : Int32, validate: {lte: 10}
  end

  def call
    params[:how_many_times].times do
      text("Knock-knock #{params[:who]}\n")
    end
  end
end

router = Prism::Router.new do
  get "/:who", KnockKnock
end

logger = Logger.new(STDOUT, Logger::DEBUG)
log_handler = Prism::LogHandler.new(logger)
handlers = [log_handler, router]

server = Prism::Server.new(handlers, logger)
server.bind_tcp(5000)
server.listen

#  INFO -- :   Prism::Server is listening on http://127.0.0.1:5000...
# DEBUG -- :     GET /me 200 177μs
```

```
curl -X GET -d "howManyTimes=2" http://127.0.0.1:5000/me
Knock-knock me
Knock-knock me
```

## Websockets example

We call them *Channels* for convenience.

```crystal
require "prism"

class Notifications
  include Prism::Channel

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

router = Prism::Router.new do
  ws "/notifications" do |socket, env|
    Notifications.subscribe(socket, env)
  end
end

# Later in the code...

Notifications.notify("Something happened!") # Will notify all subscribers binded to this particular Crystal process
```

## Contributing

1. Fork it ( https://github.com/vladfaust/prism/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [@vladfaust](https://github.com/vladfaust) Vlad Faust - creator, maintainer
