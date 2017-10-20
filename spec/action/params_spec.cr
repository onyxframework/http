require "../spec_helper"
require "../../src/rest/action"
require "../../src/rest/action/params"

module Rest::Action::Params::Spec
  struct RestAction < Rest::Action
    include Params

    params do
      param :id, Int32
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

  describe RestAction do
    context "with valid params" do
      response = handle_request(RestAction, Req.new(method: "GET", resource: "/?id=42&value=43"))

      it "is ok" do
        response.body.should eq "ok"
      end

      it "has id in params" do
        RestAction.last_params[:id].should eq 42
      end

      it "has value in params" do
        RestAction.last_params[:value].should eq 43
      end

      it "doesn't have time in params" do
        RestAction.last_params[:time].should eq nil
      end
    end

    context "with missing params" do
      response = handle_request(RestAction, Req.new(method: "GET", resource: "/?value=43"))

      it "updates status" do
        response.status_code.should eq 400
      end

      it "halts" do
        response.body.should eq "Parameter \"id\" is missing"
      end
    end

    context "with invalid params" do
      response = handle_request(RestAction, Req.new(method: "GET", resource: "/?id=foo"))

      it "updates status" do
        response.status_code.should eq 400
      end

      it "halts" do
        response.body.should eq "Parameter \"id\" is expected to be Int32"
      end
    end
  end
end
