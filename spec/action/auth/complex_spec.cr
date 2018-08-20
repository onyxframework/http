require "../../spec_helper"
require "../../../src/prism/action"
require "../../../src/prism/authable"
require "../../../src/prism/ext/http/request/auth"

module Prism::Action::Auth::ComplexSpec
  record User, id : Int32

  class Authable < Prism::Authable
    enum Scope
      User
      Admin
    end

    enum Level
      Rookie
      God
    end

    getter! user : User?
    @user = nil

    def initialize(@scope : Scope, @level : Level)
    end

    def auth?(scope : Scope, level : Level = Level::Rookie)
      if @scope == scope
        raise AuthorizationError.new("Wrong level") unless @level >= level
        @user = User.new(42)
      end
    end
  end

  struct StrictAction < Prism::Action
    include Auth(Authable)

    auth!(:admin, level: :god)

    def call
      context.response.print("ok")
    end
  end

  struct NonStrictAction < Prism::Action
    include Auth(Authable)

    def call
      begin
        if auth?(:admin, level: :god)
          context.response.print("ok")
        else
          context.response.print("not ok")
        end
      rescue Authable::AuthorizationError
        context.response.print("Wrong level")
      end
    end
  end

  describe StrictAction do
    context "when authed" do
      response = handle_request(StrictAction, Req.new("GET", "/").tap do |r|
        r.auth = Authable.new(:admin, :god)
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

    context "when with wrong level" do
      response = handle_request(StrictAction, Req.new("GET", "/").tap do |r|
        r.auth = Authable.new(:admin, :rookie)
      end)

      it "is unauthorized" do
        response.body.should eq "Wrong level"
        response.status_code.should eq 403
      end
    end
  end

  describe NonStrictAction do
    context "when authed" do
      response = handle_request(NonStrictAction, Req.new("GET", "/").tap do |r|
        r.auth = Authable.new(:admin, :god)
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

    context "when with wrong level" do
      response = handle_request(NonStrictAction, Req.new("GET", "/").tap do |r|
        r.auth = Authable.new(:admin, :rookie)
      end)

      it "is unauthorized" do
        response.body.should eq "Wrong level"
      end
    end
  end
end
