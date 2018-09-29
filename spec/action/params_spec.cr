require "../spec_helper"
require "../../src/prism/action"

module Prism::Action::Params::Spec
  struct PrismAction
    include Prism::Action
    include Prism::Action::Params

    preserve_body

    params do
      type id : Int32
      type value : Int32?
      type time : Time?
    end

    @@last_params = uninitialized ParamsTuple
    class_getter last_params

    @@last_body = uninitialized String?
    class_getter last_body

    def call
      @@last_body = body
      @@last_params = params
      context.response.print("ok")
    end
  end

  describe PrismAction do
    context "with valid params" do
      response = handle_request(PrismAction, Req.new(method: "GET", resource: "/?id=42&value=43"))

      it "is ok" do
        response.body.should eq "ok"
      end

      it "has id in params" do
        PrismAction.last_params[:id].should eq 42
      end

      it "has value in params" do
        PrismAction.last_params[:value].should eq 43
      end

      it "doesn't have time in params" do
        PrismAction.last_params[:time].should eq nil
      end
    end

    context "with missing params" do
      response = handle_request(PrismAction, Req.new(method: "GET", resource: "/?value=43"))

      it "updates status" do
        response.status_code.should eq 422
      end

      it "halts" do
        response.body.should eq "Parameter \"id\" is missing"
      end
    end

    context "with invalid params types" do
      response = handle_request(PrismAction, Req.new(method: "GET", resource: "/?id=foo"))

      it "updates status" do
        response.status_code.should eq 422
      end

      it "halts" do
        response.body.should eq "Parameter \"id\" is expected to be Int32 (given \"foo\")"
      end
    end

    context "with JSON body" do
      response = handle_request(PrismAction, Req.new(
        method: "POST",
        resource: "/",
        headers: HTTP::Headers{"Content-Type" => "application/json"},
        body: {
          id:    42,
          value: 43,
        }.to_json))

      it "is ok" do
        response.body.should eq "ok"
      end

      it "preserves body" do
        (PrismAction.last_body.not_nil!.size > 0).should be_true
      end
    end

    pending "with multipart/form-data body" do
      io = IO::Memory.new
      content_type = uninitialized String

      HTTP::FormData.build(io, "boundary") do |builder|
        content_type = builder.content_type
        builder.field("id", "42")
        builder.field("value", "43")
      end

      response = handle_request(PrismAction, Req.new(
        method: "POST",
        resource: "/",
        headers: HTTP::Headers{"Content-Type" => content_type},
        body: io.to_s))

      it "is ok" do
        response.body.should eq "ok"
      end

      it "preserves body" do
        (PrismAction.last_body.not_nil!.size > 0).should be_true
      end
    end

    context "with application/x-www-form-urlencoded body" do
      response = handle_request(PrismAction, Req.new(
        method: "POST",
        resource: "/",
        headers: HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"},
        body: HTTP::Params.encode({
          "id"    => "42",
          "value" => "43",
        })))

      it "is ok" do
        response.body.should eq "ok"
      end

      it "preserves body" do
        (PrismAction.last_body.not_nil!.size > 0).should be_true
      end
    end
  end
end
