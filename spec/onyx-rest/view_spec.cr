require "../spec_helper"

class Spec::View
  struct TestView
    include Onyx::HTTP::View

    def initialize(@foo : String, @bar : Int32? = nil)
    end

    template("./view/test.ecr")

    json foo: @foo, bar: @bar

    json content_type: "application/json-a" do
      builder do
        field "foo", @foo
        field "bar", @bar
      end
    end

    json @foo.chars.map { |c| c.upcase.to_s }, content_type: "application/json-b"

    text "foo: #{@foo}, bar: #{@bar}"

    xml do
      element("foo") do
        attribute("foo", @foo)
        attribute("bar", @bar)
      end
    end

    # Will be the default one
    text "bar: #{@bar}, foo: #{@foo}", content_type: "text/alternative", accept: {"text/alternative"}
  end

  class Server
    def initialize
      renderer = Onyx::HTTP::Middleware::Renderer.new
      rescuer = Onyx::HTTP::Middleware::Rescuer::Silent(Exception).new(renderer)
      router = Onyx::HTTP::Middleware::Router.new do
        get "/" do |env|
          TestView.new("baz")
        end
      end

      @server = Onyx::HTTP::Server.new(rescuer, router, renderer)
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

describe Onyx::HTTP::View do
  view = Spec::View::TestView.new("baz", 42)

  describe "#render_to_application_json" do
    it do
      io = IO::Memory.new
      view.render_to_application_json(io)
      io.to_s.should eq %Q[{"foo":"baz","bar":42}]
    end
  end

  describe "#render_to_application_json_a" do
    it do
      io = IO::Memory.new
      view.render_to_application_json_a(io)
      io.to_s.should eq %Q[{"foo":"baz","bar":42}]
    end
  end

  describe "#render_to_application_json_b" do
    it do
      io = IO::Memory.new
      view.render_to_application_json_b(io)
      io.to_s.should eq %Q{["B","A","Z"]}
    end
  end

  describe "#render_to_text_plain" do
    it do
      io = IO::Memory.new
      view.render_to_text_plain(io)
      io.to_s.should eq "foo: baz, bar: 42"
    end
  end

  describe "#render_to_text_alternative" do
    it do
      io = IO::Memory.new
      view.render_to_text_alternative(io)
      io.to_s.should eq "bar: 42, foo: baz"
    end
  end

  describe "#render_to_text_html" do
    it do
      io = IO::Memory.new
      view.render_to_text_html(io)
      io.to_s.should eq "<p>foo = baz, bar = 42</p>\n"
    end
  end

  describe "#render_to_application_xml" do
    it do
      io = IO::Memory.new
      view.render_to_application_xml(io)
      io.to_s.should eq %Q[<?xml version="1.0"?>\n<foo foo="baz" bar="42"/>\n]
    end
  end

  context "with server" do
    server = Spec::View::Server.new
    spawn server.start
    sleep(0.1)

    client = HTTP::Client.new(URI.parse("http://localhost:4890"))

    it do
      response = client.get("/")
      response.status_code.should eq 200
      response.headers["Content-Type"].should eq "text/alternative"
      response.body.should eq "bar: , foo: baz"
    end

    server.stop
  end
end
