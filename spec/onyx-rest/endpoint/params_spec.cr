require "../endpoint_spec"

class Spec::Endpoint::Params
  struct Endpoint
    include Onyx::HTTP::Endpoint

    params do
      path do
        type foo : String
        type bar : Int32
      end

      query do
        type foo : Int32
        type nested, nilable: true do
          type subnested do
            type ary : Array(Int32)
          end

          type bar : Float32, key: "baz"
        end
        type qux : Bool?
      end

      form do
        type foo : Int32
        type nested, nilable: true do
          type subnested do
            type ary : Array(Int32)
          end

          type bar : Float32, key: "baz"
        end
        type qux : Bool?
      end

      json do
        type foo : Int32
        type nested, nilable: true do
          type subnested do
            type ary : Array(Int32)
          end

          type bar : Float32, key: "baz"
        end
        type qux : Bool?
      end
    end

    def call
      context.response << "path: foo = " << params.path.foo << ", bar = " << params.path.bar
      context.response << "\nquery: foo = " << params.query.foo << ", nested.subnested.ary = " << params.query.nested.try(&.subnested.ary) << ", nested.bar = " << params.query.nested.try(&.bar) << ", qux = " << params.query.qux
      if form = params.form
        context.response << "\nform: foo = " << form.foo << ", nested.subnested.ary = " << form.nested.try(&.subnested.ary) << ", nested.bar = " << form.nested.try(&.bar) << ", qux = " << form.qux
      elsif json = params.json
        context.response << "\njson: foo = " << json.foo << ", nested.subnested.ary = " << json.nested.try(&.subnested.ary) << ", nested.bar = " << json.nested.try(&.bar) << ", qux = " << json.qux
      end
    end
  end

  struct FormEndpoint
    include Onyx::HTTP::Endpoint

    params do
      form require: true do
        type foo : Int32
      end
    end

    def call
      context.response << params.form.foo
    end
  end

  class Server
    def initialize
      router = Onyx::HTTP::Middleware::Router.new do |r|
        r.on "/:foo" do
          r.post "/:bar", Endpoint
        end

        r.post "/form", FormEndpoint
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

describe "Onyx::HTTP::Endpoint .params" do
  server = Spec::Endpoint::Params::Server.new
  spawn server.start

  sleep(0.1)

  client = HTTP::Client.new(URI.parse("http://localhost:4890"))

  context "without request body" do
    it do
      response = client.post("/baz/42?foo=17&nested[subnested][ary][0]=1&nested[subnested][ary][1]=2&nested[baz]=22.5&qux=true")
      response.status_code.should eq 200
      response.body.should eq <<-TEXT
      path: foo = baz, bar = 42
      query: foo = 17, nested.subnested.ary = [1, 2], nested.bar = 22.5, qux = true
      TEXT
    end
  end

  context "with form" do
    it do
      response = client.post("/baz/42?foo=17", headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}, body: "foo=17&nested[subnested][ary][0]=1&nested[subnested][ary][1]=2&nested[baz]=22.5&qux=true")
      response.status_code.should eq 200
      response.body.should eq <<-TEXT
      path: foo = baz, bar = 42
      query: foo = 17, nested.subnested.ary = , nested.bar = , qux = \nform: foo = 17, nested.subnested.ary = [1, 2], nested.bar = 22.5, qux = true
      TEXT
    end
  end

  context "with JSON" do
    it do
      response = client.post(
        "/baz/42?foo=17",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
        body: {
          foo:    17,
          nested: {
            subnested: {
              ary: [1, 2],
            },
            baz: 22.5,
          },
          qux: true,
        }.to_json
      )
      response.status_code.should eq 200
      response.body.should eq <<-TEXT
      path: foo = baz, bar = 42
      query: foo = 17, nested.subnested.ary = , nested.bar = , qux = \njson: foo = 17, nested.subnested.ary = [1, 2], nested.bar = 22.5, qux = true
      TEXT
    end
  end

  context "when form is required" do
    context "without content type" do
      it do
        response = client.post("/form", body: "foo=42")
        response.status_code.should eq 200
        response.body.should eq "42"
      end
    end

    context "with invalid content type" do
      it do
        response = client.post("/form", headers: HTTP::Headers{"Content-Type" => "bar"}, body: "foo=42")
        response.status_code.should eq 200
        response.body.should eq "42"
      end
    end

    context "with valid content type" do
      it do
        response = client.post("/form", headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}, body: "foo=42")
        response.status_code.should eq 200
        response.body.should eq "42"
      end
    end

    context "with invalid payload" do
      it do
        response = client.post("/form", headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}, body: "foo=bar")
        response.status_code.should eq 400
        response.body.should eq %q[400 Form Error — Form parameter "foo" cannot be cast from "bar" to Int32]
      end
    end
  end

  server.stop
end
