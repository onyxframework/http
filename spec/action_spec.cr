require "./spec_helper"
require "../src/prism/action"

struct Prism::Action
  module Specs
    struct OkAction < Prism::Action
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
  end

  struct JsonAction < Prism::Action
    def call
      json({"foo" => "bar"})
    end
  end

  describe JsonAction do
    response = handle_request(JsonAction)

    it "prints JSON" do
      response.body.should eq %Q[{"foo":"bar"}]
    end
  end

  struct HaltAction < Prism::Action
    class_property unwanted_calls_count = 0

    def call
      halt!(404, "Not found")

      @@unwanted_calls_count += 1
      text("ok")
    end
  end

  describe HaltAction do
    response = handle_request(HaltAction)

    it "updates status code" do
      response.status_code.should eq 404
    end

    it "prints message" do
      response.body.should eq "Not found"
    end

    it "stops execution" do
      HaltAction.unwanted_calls_count.should eq 0
    end
  end

  struct BodyAction < Prism::Action
    class_property last_body : String? = nil

    def call
      @@last_body = body
      text(context.request.body.not_nil!.gets_to_end)
    end
  end

  describe BodyAction do
    response = handle_request(BodyAction, Req.new("GET", "/", body: "foo"))

    it "copies to #body" do
      BodyAction.last_body.should eq "foo"
    end

    it "preserves original body" do
      response.body.should eq "foo"
    end
  end

  struct CallbacksAction < Prism::Action
    class_property buffer = [] of String

    def before
      @@buffer << "before"
    end

    def around
      @@buffer << "around_before"
      yield
      @@buffer << "around_after"
    end

    def call
      @@buffer << "call"
    end

    def after
      @@buffer << "after"
    end
  end

  describe CallbacksAction do
    response = handle_request(CallbacksAction)

    it do
      CallbacksAction.buffer.should eq ["before", "around_before", "call", "around_after", "after"]
    end
  end
end
