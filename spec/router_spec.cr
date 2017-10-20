require "./spec_helper"
require "../src/rest/router"

class Rest::Router
  module Specs
    router = Rest::Router.new do |r|
      r.get "/users/:id" do |env|
        env.response.print("id = #{env.request.path_params.not_nil!["id"]}")
      end

      r.post "/foo" do |env|
        env.response.print("foo")
      end
    end

    describe Rest::Router do
      context "get /users/42" do
        context = dummy_context(Req.new("GET", "/users/42"))
        router.call(context)

        it "updates request action" do
          context.request.action.should be_a(::Proc(HTTP::Server::Context, Nil))
        end

        it "updates path params" do
          context.request.path_params.should eq({"id" => "42"})
        end
      end

      context "post /foo" do
        context = dummy_context(Req.new("POST", "/foo"))
        router.call(context)

        it "updates request action" do
          context.request.action.should be_a(::Proc(HTTP::Server::Context, Nil))
        end

        it "sets empty path params" do
          context.request.path_params.not_nil!.empty?.should be_true
        end
      end

      context "get /unknown" do
        context = dummy_context(Req.new("GET", "/unknown"))
        router.call(context)

        it "doesn't update request action" do
          context.request.action.should be_nil
        end

        it "doesn't update path params" do
          context.request.path_params.should be_nil
        end
      end
    end
  end
end
