require "../../spec_helper"
require "../../../src/onyx-rest/renderers/plain"

struct PlainView
  include Onyx::REST::View

  def initialize(@foo : String)
  end

  # `Renderers::Template` is required in another spec,
  # therefore Crystal assumes this view could be invoked with #render as well
  template("./templates/test.ecr")

  text("foo: #{@foo}")

  # `Renderers::JSON` is required too in another spec,
  # therefore Crystal assumes this view could be invoked with #to_json as well
  json(raise NotImplementedError.new(self))
end

class PlainError < Onyx::REST::Error(505)
  def initialize(@foo : String)
    super(@foo)
  end

  def payload
    {foo: @foo}
  end
end

class PlainRendererSpecServer
  def initialize
    renderer = Onyx::REST::Renderers::Plain.new
    router = Onyx::HTTP::Router.new do
      get "/" do |env|
        if env.request.query_params["raise"]?
          env.response.error = PlainError.new("Boom!")
        else
          env.response.view = PlainView.new("OK")
        end
      end

      get "/empty" { }
    end

    @server = Onyx::HTTP::Server.new([router, renderer])
  end

  getter server
end

describe Onyx::REST::Renderers::Plain do
  server = PlainRendererSpecServer.new

  spawn do
    server.server.bind_tcp(4890)
    server.server.listen
  end

  sleep(0.1)

  client = HTTP::Client.new(URI.parse("http://localhost:4890"))

  describe "view rendering" do
    it do
      response = client.get("/")
      response.status_code.should eq 200
      response.headers["Content-Type"].should eq "text/plain; charset=utf-8"
      response.body.should eq "foo: OK"
    end
  end

  describe "error rendering" do
    it do
      response = client.get("/?raise=true")
      response.status_code.should eq 505
      response.headers["Content-Type"].should eq "text/plain; charset=utf-8"
      response.body.should eq "505 Boom!"
    end
  end

  describe "skip rendering" do
    it do
      response = client.get("/empty")
      response.status_code.should eq 200
      response.headers["Content-Type"]?.should be_nil
      response.body.should eq ""
    end
  end

  server.server.close
end
