require "./spec_helper"
require "../src/prism/server"

describe Prism::Server do
  router = Prism::Router.new do
    get "/" do |env|
      env.response.print("Hello Prism!")
    end
  end

  server = Prism::Server.new([router], name: "Test server")

  it "works" do
    spawn do
      server.bind_tcp(5042)
      server.listen
    end

    sleep(0.5)

    response = HTTP::Client.get("http://localhost:5042")
    response.body.should eq "Hello Prism!"

    server.close
  end
end
