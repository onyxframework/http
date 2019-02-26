require "../spec_helper"

class TestChannel
  include Onyx::REST::Channel

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

class ChannelTestServer
  getter server

  def initialize
    rescuer = Onyx::REST::Rescuer.new
    router = Onyx::HTTP::Router.new do
      ws "/test/:id", TestChannel
    end

    @server = Onyx::HTTP::Server.new([rescuer, router])
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

describe Onyx::REST::Channel do
  server = ChannelTestServer.new

  spawn do
    server.server.bind_tcp(4890)
    server.server.listen
  end

  sleep(0.1)

  context "with invalid ID" do
    it "closes socket with 4004" do
      ws_error = nil
      socket = HTTP::WebSocket.new(URI.parse("ws://localhost:4890/test/1"))

      socket.on_close do |frame|
        ws_error = WebSocketError.new(frame)
      end

      spawn socket.run

      sleep(0.5)

      ws_error.should be_a(WebSocketError)
      ws_error.not_nil!.reason.should eq "User Not Found"
      ws_error.not_nil!.code.should eq 4004_i16
    end
  end

  context "with invalid query param" do
    it "closes socket with 4000" do
      ws_error = nil
      socket = HTTP::WebSocket.new(URI.parse("ws://localhost:4890/test/1?foo=bar"))

      socket.on_close do |frame|
        ws_error = WebSocketError.new(frame)
      end

      spawn socket.run

      sleep(0.5)

      ws_error.should be_a(WebSocketError)
      ws_error.not_nil!.reason.should eq %Q[Query parameter "foo" cannot be cast from "bar" to (Int32 | Nil)]
      ws_error.not_nil!.code.should eq 4000_i16
    end
  end

  describe "on_open" do
    socket = HTTP::WebSocket.new(URI.parse("ws://localhost:4890/test/42"))
    latest_message = nil

    socket.on_message do |frame|
      latest_message = frame
    end

    spawn socket.run

    sleep(0.5)

    it do
      latest_message.should eq "Oh, hi Mark"
    end
  end

  server.server.close
end
