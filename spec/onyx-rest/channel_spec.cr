require "../spec_helper"

class Spec::Channel
  class Channel
    include Onyx::HTTP::Channel

    params do
      path do
        type id : Int32
      end

      query do
        type foo : Int32?
      end
    end

    errors do
      type UserNotFound(4004)
    end

    def on_open
      raise UserNotFound.new unless params.path.id == 42
      socket.send("Oh, hi Mark")
    end

    def on_message(message)
      socket.send(message)
    end
  end

  class Server
    def initialize
      renderer = Onyx::HTTP::Middleware::Renderer.new
      rescuer = Onyx::HTTP::Middleware::Rescuer::Silent(Exception).new(renderer)
      router = Onyx::HTTP::Middleware::Router.new do
        ws "/test/:id", Channel
      end

      @server = Onyx::HTTP::Server.new([rescuer, router])
    end

    def start
      @server.bind_tcp(4890)
      @server.listen
    end

    def stop
      @server.close
    end
  end
end

struct WebSocketError
  getter reason : String? = nil
  getter code : Int16? = nil

  def initialize(frame : String)
    unless frame.empty?
      @code = IO::ByteFormat::BigEndian.decode(Int16, frame[0..1].to_slice)

      if frame.size > 2
        @reason = frame[2..-1]
      end
    end
  end
end

describe Onyx::HTTP::Channel do
  server = Spec::Channel::Server.new
  spawn server.start
  sleep(0.1)

  context "with invalid ID" do
    it "closes socket with 4004" do
      ws_error = nil
      socket = HTTP::WebSocket.new(URI.parse("ws://localhost:4890/test/1"))

      socket.on_close do |frame|
        ws_error = WebSocketError.new(frame)
      end

      spawn socket.run

      sleep(0.1)

      ws_error.should be_a(WebSocketError)
      ws_error.not_nil!.reason.should eq "User Not Found"
      ws_error.not_nil!.code.should eq 4004_i16
    end
  end

  context "with invalid query param" do
    pending "returns an HTTP error" do
      socket = HTTP::WebSocket.new(URI.parse("ws://localhost:4890/test/1?foo=bar"))
      spawn socket.run
      sleep(0.1)

      # TODO: Somehow check the underlying HTTP response status_code and body
    end
  end

  describe "on_open" do
    socket = HTTP::WebSocket.new(URI.parse("ws://localhost:4890/test/42"))
    latest_message = nil

    socket.on_message do |frame|
      latest_message = frame
    end

    spawn socket.run

    sleep(0.1)

    it do
      latest_message.should eq "Oh, hi Mark"
    end
  end

  server.stop
end
