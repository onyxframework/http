require "../../spec_helper"
require "../../../src/onyx-rest/renderer/json"

struct JSONView
  include Onyx::REST::View

  def initialize(@foo : String)
  end

  # `Renderer::Template` is required in another spec,
  # therefore Crystal assumes this view could be invoked with #render as well
  template("./templates/test.ecr")

  json({foo: @foo})

  # `Renderer::Text` is required in another spec,
  # therefore Crystal assumes this view could be invoked with #to_text as well
  text(raise NotImplementedError.new(self))
end

class JSONError < Onyx::REST::Error(505)
  def initialize(@foo : String)
    super(@foo)
  end

  def payload
    {foo: @foo}
  end
end

class EmptyJSONError < Onyx::REST::Error(506)
end

class JSONRendererSpecServer
  def initialize
    renderer = Onyx::REST::Renderer::JSON.new
    router = Onyx::HTTP::Router.new do
      get "/" do |env|
        if env.request.query_params["raise"]?
          env.response.error = JSONError.new("Boom!")
        else
          env.response.view = JSONView.new("OK")
        end
      end

      get "/empty" { }
      get "/empty_error" do |env|
        env.response.error = EmptyJSONError.new
      end
    end

    @server = Onyx::HTTP::Server.new([router, renderer])
  end

  getter server
end

describe Onyx::REST::Renderer::JSON do
  server = JSONRendererSpecServer.new

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
      response.headers["Content-Type"].should eq "application/json; charset=utf-8"
      response.body.should eq %Q[{"foo":"OK"}]
    end
  end

  describe "error rendering" do
    it do
      response = client.get("/?raise=true")
      response.status_code.should eq 505
      response.headers["Content-Type"].should eq "application/json; charset=utf-8"
      response.body.should eq %Q[{"error":{"class":"JSONError","message":"Boom!","code":505,"payload":{"foo":"Boom!"}}}]
    end

    it do
      response = client.get("/empty_error")
      response.status_code.should eq 506
      response.headers["Content-Type"].should eq "application/json; charset=utf-8"
      response.body.should eq %Q[{"error":{"class":"EmptyJSONError","message":"Empty json error","code":506,"payload":null}}]
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
