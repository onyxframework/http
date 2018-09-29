require "./spec_helper"
require "../src/prism/action"

module Prism::Action
  struct OkAction
    include Prism::Action

    def call
      status(205)
      text("ok")
    end
  end

  describe OkAction do
    response = handle_request(OkAction)

    it "prints ok" do
      response.body.should eq "ok"
    end

    it "updates status code" do
      response.status_code.should eq 205
    end
  end

  struct OkActionWithStatus
    include Prism::Action

    def call
      text(205, "ok")
    end
  end

  describe OkActionWithStatus do
    response = handle_request(OkActionWithStatus)

    it "prints ok" do
      response.body.should eq "ok"
    end

    it "updates status code" do
      response.status_code.should eq 205
    end
  end

  struct JsonAction
    include Prism::Action

    def call
      json({"foo" => "bar"})
    end
  end

  describe JsonAction do
    response = handle_request(JsonAction)

    it "prints JSON" do
      response.body.should eq %Q[{"foo":"bar"}]
    end

    it "sets content type header" do
      response.headers["Content-Type"].should eq "application/json; charset=utf-8"
    end
  end

  struct JsonWithStatusAction
    include Prism::Action

    def call
      json(201, {
        foo: "bar",
      })
    end
  end

  describe JsonWithStatusAction do
    response = handle_request(JsonWithStatusAction)

    it "prints JSON" do
      response.body.should eq %Q[{"foo":"bar"}]
    end

    it "updates status code" do
      response.status_code.should eq 201
    end

    it "sets content type header" do
      response.headers["Content-Type"].should eq "application/json; charset=utf-8"
    end
  end

  struct HaltAction
    include Prism::Action

    class_property unwanted_calls_count = 0

    def call
      halt(404)

      @@unwanted_calls_count += 1
      text("ok")
    end
  end

  describe HaltAction do
    response = handle_request(HaltAction)

    it "updates status code" do
      response.status_code.should eq 404
    end

    it "prints default message" do
      response.body.should eq "Not Found"
    end

    it "stops execution" do
      HaltAction.unwanted_calls_count.should eq 0
    end
  end

  struct TextHaltAction
    include Prism::Action

    def call
      halt(404, "Nope")
    end
  end

  describe TextHaltAction do
    response = handle_request(TextHaltAction)

    it "prints specified response" do
      response.body.should eq("Nope")
    end
  end

  struct JSONHaltAction
    include Prism::Action

    def call
      halt(403, {error: "Oops"})
    end
  end

  describe JSONHaltAction do
    response = handle_request(JSONHaltAction)

    it "prints JSON response" do
      response.body.should eq(%Q[{"error":"Oops"}])
    end
  end

  struct BodyAction
    include Prism::Action

    class_property last_body : String? = nil

    def call
      text(body)
    end
  end

  describe BodyAction do
    response = handle_request(BodyAction, Req.new("GET", "/", body: "foo"))

    it do
      response.body.should eq "foo"
    end
  end

  struct CallbacksAction
    include Prism::Action

    class_property buffer = [] of String

    before do
      @@buffer << "before"
    end

    around do
      @@buffer << "around_before"
      yield
      @@buffer << "around_after"
    end

    def call
      @@buffer << "call"
    end

    after do
      @@buffer << "after"
    end
  end

  describe CallbacksAction do
    response = handle_request(CallbacksAction)

    it do
      CallbacksAction.buffer.should eq ["before", "around_before", "call", "around_after", "after"]
    end
  end

  struct HeaderAction
    include Prism::Action

    def call
      header("Custom", "42")
    end
  end

  describe HeaderAction do
    response = handle_request(HeaderAction)

    it do
      response.headers["Custom"].should eq "42"
    end
  end

  struct RedirectAction
    include Prism::Action

    def call
      redirect(URI.parse("https://github.com/vladfaust/prism"), 301)
      text("Doesn't halt")
    end
  end

  describe RedirectAction do
    response = handle_request(RedirectAction)

    it do
      response.headers["Location"].should eq "https://github.com/vladfaust/prism"
      response.status_code.should eq 301
      response.body.should eq "Doesn't halt"
    end
  end
end
