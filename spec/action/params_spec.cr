require "../spec_helper"
require "../../src/prism/action"
require "../../src/prism/action/params"

module Prism::Action::Params::Spec
  struct PrismAction < Prism::Action
    include Params

    params do
      param :id, Int32, validate: {min: 42}
      param :value, Int32?
      param :time, Time?
    end

    @@last_params = uninitialized ParamsTuple
    class_getter last_params

    def call
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
        response.body.should eq "Parameter \"id\" is expected to be Int32 (given foo)"
      end
    end

    context "with invalid params" do
      response = handle_request(PrismAction, Req.new(method: "GET", resource: "/?id=41"))

      it "updates status" do
        response.status_code.should eq 422
      end

      it "halts" do
        response.body.should eq "Parameter \"id\" must be greater or equal to 42"
      end
    end
  end
end
