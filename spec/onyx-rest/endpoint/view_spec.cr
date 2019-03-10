require "../endpoint_spec"

module Spec::Endpoint::View
  struct TheView
    include Onyx::HTTP::View

    def initialize(@foo : String)
    end

    text "foo = #{@foo}"
  end

  struct Endpoint
    include Onyx::HTTP::Endpoint

    def call
      TheView.new("bar")
    end
  end

  class Server
    def initialize
      router = Onyx::HTTP::Middleware::Router.new do
        get "/", Endpoint
      end

      renderer = Onyx::HTTP::Middleware::Renderer.new
      rescuer = Onyx::HTTP::Middleware::Rescuer::Silent(Exception).new(renderer)

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

describe Onyx::HTTP::Endpoint do
  server = Spec::Endpoint::View::Server.new
  spawn server.start
  sleep(0.1)

  client = HTTP::Client.new(URI.parse("http://localhost:4890"))

  it "renders returned views" do
    response = client.get("/")
    response.status_code.should eq 200
    response.body.should eq "foo = bar"
  end

  server.stop
end
