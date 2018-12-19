require "http/client"
require "./spec_helper"
require "./json_server"
require "./plain_text_server"

describe Onyx::REST do
  describe "plain text server" do
    port = 4890

    server = PlainTextServer.new
    server.bind_tcp(port)

    spawn do
      server.listen
    end

    sleep 0.5

    client = HTTP::Client.new("localhost", port)

    describe "/" do
      it do
        response = client.get("/")
        response.status_code.should eq 200
        response.body.should eq "Hello Onyx\n"
      end
    end

    describe "/error" do
      it do
        response = client.get("/error")
        response.status_code.should eq 500
        response.body.should eq "500 Internal Server Error\n"
      end
    end

    describe "/coffee" do
      it do
        response = client.get("/coffee")
        response.status_code.should eq 419
        response.body.should eq "419 I am a coffeepot ☕️\n"
      end
    end

    describe "/params" do
      it do
        response = client.get("/params?foo=42")
        response.status_code.should eq 200
        response.body.should eq "foo = 42\n"
      end

      it do
        response = client.get("/params?foo=bar")
        response.status_code.should eq 400
        response.body.should eq "400 Parameter \"foo\" cannot be cast from \"bar\" to Int32\n"
      end

      it do
        response = client.get("/params")
        response.status_code.should eq 400
        response.body.should eq "400 Parameter \"foo\" is missing\n"
      end
    end

    describe "/unknown" do
      it do
        response = client.get("/unknown")
        response.status_code.should eq 404
        response.body.should eq "404 Not Found\n"
      end
    end
  end

  describe "JSON server" do
    port = 4891

    server = JSONServer.new
    server.bind_tcp(port)

    spawn do
      server.listen
    end

    sleep 0.5

    client = HTTP::Client.new("localhost", port)

    describe "/" do
      it do
        response = client.get("/")
        response.status_code.should eq 200
        response.body.should eq %Q[{"hello":"onyx"}\n]
      end
    end

    describe "/error" do
      it do
        response = client.get("/error")
        response.status_code.should eq 500
        response.body.should eq %Q[{"error":{"class":"UnhandledServerError","message":"Unhandled server error. If you are the application owner, see the logs for details","code":500}}\n]
      end
    end

    describe "/coffee" do
      it do
        response = client.get("/coffee")
        response.status_code.should eq 419
        response.body.should eq %Q[{"error":{"class":"IAmACoffeepot","message":"I am a coffeepot ☕️","code":419}}\n]
      end
    end

    # FIXME: For some reason client preserves previous status code
    client = HTTP::Client.new("localhost", port)

    describe "/params" do
      it do
        response = client.get("/params?foo=42")
        response.status_code.should eq 200
        response.body.should eq %Q[{"foo":42}\n]
      end

      it do
        response = client.get("/params?foo=bar")
        response.status_code.should eq 400
        response.body.should eq %Q[{"error":{"class":"ParamsError","message":"Parameter \\"foo\\" cannot be cast from \\"bar\\" to Int32","code":400,"payload":{"path":["foo"]}}}\n]
      end

      it do
        response = client.get("/params")
        response.status_code.should eq 400
        response.body.should eq %Q[{"error":{"class":"ParamsError","message":"Parameter \\"foo\\" is missing","code":400,"payload":{"path":["foo"]}}}\n]
      end
    end

    describe "/unknown" do
      it do
        response = client.get("/unknown")
        response.status_code.should eq 404
        response.body.should eq %Q[{"error":{"class":"NotFound","message":"Not Found","code":404,"payload":{"method":"GET","path":"/unknown"}}}\n]
      end
    end
  end
end
