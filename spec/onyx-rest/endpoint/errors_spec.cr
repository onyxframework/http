require "../endpoint_spec"

class Spec::Endpoint::Errors
  struct Endpoint
    include Onyx::HTTP::Endpoint

    errors do
      type FooBar(404)
      type BazQux(405), foo : String do
        super("Baz qux, foo = #{foo}")
      end
    end

    def call
      if context.request.query_params["foo_bar"]?
        raise FooBar.new
      elsif param = context.request.query_params["baz_qux"]?
        raise BazQux.new(param)
      end
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

describe "Onyx::HTTP::Endpoint .errors" do
  server = Spec::Endpoint::Errors::Server.new
  spawn server.start
  sleep(0.1)

  client = HTTP::Client.new(URI.parse("http://localhost:4890"))

  context "with default Accept header" do
    it do
      response = client.get("/?foo_bar")
      response.status_code.should eq 404
      response.body.should eq "404 Foo Bar"
    end

    it do
      response = client.get("/?baz_qux=quux")
      response.status_code.should eq 405
      response.body.should eq "405 Baz Qux — Baz qux, foo = quux"
    end
  end

  context "with JSON Accept header" do
    it do
      response = client.get("/?foo_bar", headers: HTTP::Headers{"Accept" => "application/json"})
      response.status_code.should eq 404
      response.body.should eq %Q[{"error":{"name":"Foo Bar","message":null,"code":404,"payload":null}}]
    end

    it do
      response = client.get("/?baz_qux=quux", headers: HTTP::Headers{"Accept" => "application/json"})
      response.status_code.should eq 405
      response.body.should eq %Q[{"error":{"name":"Baz Qux","message":"Baz qux, foo = quux","code":405,"payload":{"foo":"quux"}}}]
    end
  end

  context "with HTML Accept header" do
    it do
      response = client.get("/?foo_bar", headers: HTTP::Headers{"Accept" => "text/html"})
      response.status_code.should eq 404
      response.body.should match /<h1 class="status-message">Foo Bar<\/h1>/
    end

    it do
      response = client.get("/?baz_qux=quux", headers: HTTP::Headers{"Accept" => "text/html"})
      response.status_code.should eq 405
      response.body.should match /<h1 class="status-message">Baz Qux<\/h1>/
    end
  end

  server.stop
end
