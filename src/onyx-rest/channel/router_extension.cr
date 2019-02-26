require "onyx-http/router"

class Onyx::HTTP::Router
  # Draw a `"ws://"` route for *path* binding *channel*. See `Channel`.
  #
  # ```
  # router = Onyx::REST::Router.new do
  #   ws "/foo", MyChannel
  # end
  # ```
  def ws(path, channel : REST::Channel.class)
    add("/ws" + path, ::HTTP::WebSocketHandler.new do |socket, context|
      channel.bind(socket, context)
    end)
  end
end
