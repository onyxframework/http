require "../../spec_helper"
require "../../../src/prism/action"
require "../../../src/prism/authenticator"
require "../../../src/prism/ext/http/request/auth"

module Prism::Action::Auth::SimpleSpec
  class Authenticator
    include Prism::Authenticator

    def initialize(@token : String)
    end

    def authenticate
      @token == "authme"
    end
  end

  struct StrictAction
    include Prism::Action
    include Prism::Action::Auth(Authenticator)

    authenticate

    def call
      context.response.print("ok")
    end
  end

  struct NonStrictAction
    include Prism::Action
    include Prism::Action::Auth(Authenticator)

    def call
      if auth?.try &.authenticate
        context.response.print("ok")
      else
        context.response.print("not ok")
      end
    end
  end

  describe StrictAction do
    context "when authed" do
      response = handle_request(StrictAction, Req.new("GET", "/").tap do |r|
        r.auth = Authenticator.new("authme")
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
        r.auth = Authenticator.new("authme")
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
