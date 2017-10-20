require "spec"

require "http/server"

alias Req = HTTP::Request

def handle_request(handler, request = Req.new("GET", "/"))
  io = IO::Memory.new
  response = HTTP::Server::Response.new(io)
  context = HTTP::Server::Context.new(request, response)
  handler.call(context)
  response.close
  io.rewind
  HTTP::Client::Response.from_io(io, decompress: false)
end

def dummy_context(request = Req.new("GET", "/"), response = HTTP::Server::Response.new(IO::Memory.new))
  HTTP::Server::Context.new(request: request, response: response)
end
