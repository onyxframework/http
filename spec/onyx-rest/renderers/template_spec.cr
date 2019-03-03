require "../../spec_helper"
require "../../../src/onyx-rest/renderers/template"

struct TemplateView
  include Onyx::REST::View

  def initialize(@foo : String)
  end

  template("./templates/test.ecr")

  # `Renderers::Plain` is required in another spec,
  # therefore Crystal assumes this view could be invoked with #to_text as well
  text("foo: #{@foo}")

  # `Renderers::JSON` is required in another spec,
  # therefore Crystal assumes this view could be invoked with #to_json as well
  json(raise NotImplementedError.new(self))
end

class TemplateError < Onyx::REST::Error(505)
  def initialize(@foo : String)
    super(@foo)
  end

  def payload
    {foo: @foo}
  end
end

class TemplateRendererSpecServer
  def initialize
    renderer = Onyx::REST::Renderers::Template.new
    router = Onyx::HTTP::Router.new do
      get "/" do |env|
        if env.request.query_params["raise"]?
          env.response.error = TemplateError.new("Boom!")
        else
          env.response.view = TemplateView.new("OK")
        end
      end

      get "/empty" { }
    end

    @server = Onyx::HTTP::Server.new([router, renderer])
  end

  getter server
end

describe Onyx::REST::Renderers::Template do
  server = TemplateRendererSpecServer.new

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
      response.headers["Content-Type"].should eq "text/html; charset=utf-8"
      response.body.should eq "<p>foo = OK</p>\n"
    end
  end

  describe "error rendering" do
    it do
      response = client.get("/?raise=true")
      response.status_code.should eq 505
      response.headers["Content-Type"].should eq "text/html; charset=utf-8"
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
