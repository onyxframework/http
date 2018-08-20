require "../../spec_helper"
require "../../../src/prism/action"
require "../../../src/prism/authable"
require "../../../src/prism/ext/http/request/auth"

module Prism::Action::Auth::SimpleSpec
  class Authable < Prism::Authable
    def initialize(@token : String)
    end

    def auth?
      @token == "authme"
    end
  end

  struct StrictAction < Prism::Action
    include Auth(Authable)

    auth!

    def call
      context.response.print("ok")
    end
  end

  struct NonStrictAction < Prism::Action
    include Auth(Authable)

    def call
      if auth?
        context.response.print("ok")
      else
        context.response.print("not ok")
      end
    end
  end

  describe StrictAction do
    context "when authed" do
      response = handle_request(StrictAction, Req.new("GET", "/").tap do |r|
        r.auth = Authable.new("authme")
      end)

      it "is ok" do
        response.body.should eq "ok"
      end
    end

    context "when not authed" do
      response = handle_request(StrictAction, Req.new("GET", "/"))

      it "is 401" do
        response.status_code.should eq 401
      end
    end
  end

  describe NonStrictAction do
    context "when authed" do
      response = handle_request(NonStrictAction, Req.new("GET", "/").tap do |r|
        r.auth = Authable.new("authme")
      end)

      it "is ok" do
        response.body.should eq "ok"
      end
    end

    context "when not authed" do
      response = handle_request(NonStrictAction, Req.new("GET", "/"))

      it "is not ok" do
        response.body.should eq "not ok"
      end
    end
  end
end
