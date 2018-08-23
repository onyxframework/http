require "../../spec_helper"
require "../../../src/prism/action"
require "../../../src/prism/authenticator"
require "../../../src/prism/ext/http/request/auth"

module Prism::Action::Auth::ComplexSpec
  enum ExperienceLevel
    Rookie
    Veteran
    God
  end

  record User, id : Int32, level : ExperienceLevel?
  record Merchant, id : Int32, level : ExperienceLevel?

  class Authenticator
    include Prism::Authenticator

    @user : User? = nil
    @merchant : Merchant? = nil
    @entity : User | Merchant | Nil = nil

    def initialize(@token : String)
    end

    def authenticate(*entities)
      return @entity if @entity

      token_entity = @token.split(":")[0]?.try &.downcase
      return if token_entity.nil?
      return unless entities.map(&.to_s).includes?(token_entity)

      token_level = @token.split(":")[1]?.try &.downcase
      level = ExperienceLevel.parse?(token_level) if token_level

      case token_entity
      when "user"     then @entity = @user = User.new(42, level)
      when "merchant" then @entity = @merchant = Merchant.new(42, level)
      else                 raise Exception.new("Unhandled token entity #{token_entity}")
      end
    end

    def authorize(experience_level : ExperienceLevel = :rookie)
      @entity.try &.level.try do |l|
        l >= experience_level
      end
    end

    def user?
      @user ||= authenticate(:user).try &.as(User)
    end

    def user
      user?.not_nil!
    end

    def merchant?
      @merchant ||= authenticate(:merchant).try &.as(Merchant)
    end

    def merchant
      merchant?.not_nil!
    end
  end

  struct StrictAction
    include Prism::Action
    include Prism::Action::Auth(Authenticator)

    authenticate :user, :merchant
    authorize experience_level: :god

    def call
      context.response.print("ok")
    end
  end

  describe StrictAction do
    context "when authed" do
      response = handle_request(StrictAction, Req.new("GET", "/").tap do |r|
        r.auth = Authenticator.new("merchant:god")
      end)

      it "is ok" do
        response.status_code.should eq 200
        response.body.should eq "ok"
      end
    end

    context "when not authed" do
      response = handle_request(StrictAction, Req.new("GET", "/"))

      it "has 401 code" do
        response.status_code.should eq 401
      end
    end

    context "when with low level" do
      response = handle_request(StrictAction, Req.new("GET", "/").tap do |r|
        r.auth = Authenticator.new("user:veteran")
      end)

      it "has 403 code" do
        response.status_code.should eq 403
      end
    end
  end

  struct NonStrictAction
    include Prism::Action
    include Prism::Action::Auth(Authenticator)

    def call
      if auth?.try &.user?
        # TODO: Optimize when https://github.com/crystal-lang/crystal/issues/6592 is solved
        case auth.user.level
        when nil              then context.response.print("who are you again?")
        when .rookie?         then context.response.print("hi, rookie")
        when .veteran?, .god? then context.response.print("hello, mighty #{auth.user.level.to_s.underscore}")
        end
      elsif auth?.try &.merchant?
        context.response.print(auth.authorize(:veteran) ? "welcome" : "nope")
      else
        context.response.print("not authenticated at all")
      end
    end
  end

  describe NonStrictAction do
    context "when authed" do
      context "as user" do
        context "with rookie level" do
          response = handle_request(NonStrictAction, Req.new("GET", "/").tap do |r|
            r.auth = Authenticator.new("user:rookie")
          end)

          it "is ok" do
            response.body.should eq "hi, rookie"
          end
        end

        context "with veteran or god level" do
          response = handle_request(NonStrictAction, Req.new("GET", "/").tap do |r|
            r.auth = Authenticator.new("user:veteran")
          end)

          it "is ok" do
            response.body.should eq "hello, mighty veteran"
          end
        end

        context "with unknown level" do
          response = handle_request(NonStrictAction, Req.new("GET", "/").tap do |r|
            r.auth = Authenticator.new("user:h@ck3r")
          end)

          it "is ok" do
            response.body.should eq "who are you again?"
          end
        end
      end

      context "as merchant" do
        context "with rookie level" do
          response = handle_request(NonStrictAction, Req.new("GET", "/").tap do |r|
            r.auth = Authenticator.new("merchant:rookie")
          end)

          it "is ok" do
            response.body.should eq "nope"
          end
        end

        context "with veteran or god level" do
          response = handle_request(NonStrictAction, Req.new("GET", "/").tap do |r|
            r.auth = Authenticator.new("merchant:veteran")
          end)

          it "is ok" do
            response.body.should eq "welcome"
          end
        end

        context "with unknown level" do
          response = handle_request(NonStrictAction, Req.new("GET", "/").tap do |r|
            r.auth = Authenticator.new("merchant:h@ck3r")
          end)

          it "is ok" do
            response.body.should eq "nope"
          end
        end
      end
    end

    context "when not authed" do
      response = handle_request(NonStrictAction, Req.new("GET", "/"))

      it "is not ok" do
        response.body.should eq "not authenticated at all"
      end
    end
  end
end
