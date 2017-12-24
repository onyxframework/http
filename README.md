<p align="center">
   <img src="https://user-images.githubusercontent.com/7955682/34328806-bc11f268-e8fa-11e7-9c7d-2c852578546f.png" width="512" />
</p>
<p align="center">
   Prism is an expressive action-oriented modular web framework.
</p>
<p align="center">
   <a href="https://crystal-lang.org/">
      <img src="https://img.shields.io/badge/built%20with-crystal-000000.svg?style=flat-square" /></a>
   <a href="https://travis-ci.org/vladfaust/prism">
      <img src="https://img.shields.io/travis/vladfaust/prism/master.svg?style=flat-square" /></a>
   <a href="https://vladfaust.com/prism">
      <img src="https://img.shields.io/badge/docs-available-brightgreen.svg?style=flat-square" /></a>
   <a href="https://github.com/vladfaust/prism/releases">
      <img src="https://img.shields.io/github/release/vladfaust/prism.svg?style=flat-square" /></a>
</p>

## Features

- Modular approach avoiding singleton configurations.
- Safe params typecasting and validation.
- Expressive actions definition.
- ⚡️ Websockets built-in.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  prism:
    github: vladfaust/prism
```

This shard follows [Semantic Versioning v2.0.0](http://semver.org/).

## Basic example

Please refer to the documentation available online at [vladfaust.com/prism](https://vladfaust.com/prism).

```crystal
require "prism"

struct KnockKnock < Prism::Action
  include Params

  params do
    param :who, String
    param :times, Int32, validate: {max: 10}
  end

  def call
    params[:times].times do
      text("Knock-knock #{who}\n")
    end
  end
end

router = Prism::Router.new do |r|
  r.get "/:who" do |env|
    KnockKnock.call(env)
  end
end

logger = Logger.new(STDOUT)
log_handler = Prism::Logger.new(logger)
handlers = [log_handler, router]

server = Prism::Server.new("localhost", 5000, handlers, logger)
server.listen

#  INFO -- :   Prism server v0.1.0 is listening on http://localhost:5000...
```

## Websockets example

We call them *Channels* for convenience.

```crystal
require "prism"

class Notifications < Prism::Channel
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

router = Prism::Router.new do |r|
  r.ws "/notifications" do |socket, env|
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
