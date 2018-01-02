require "./spec_helper"
require "../src/prism/params"

module Prism::Params::Specs
  class SimpleAction
    include Prism::Params

    params do
      param :id, Int32, validate: {min: 42}
      param :value, Int32?
      param :time, Time?
      param :float_value, Float64?
      param :"kebab-param", String?, proc: ->(p : String) { p.upcase }
    end

    @@last_params = uninitialized ParamsTuple
    class_getter last_params

    def self.call(context)
      params = parse_params(context)
      @@last_params = params
      context.response.print("ok")
    end
  end

  describe SimpleAction do
    context "with valid params" do
      response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&value=42&time=1506952232&kebab-param=foo"))

      it "doesn't halt" do
        response.body.should eq "ok"
      end

      it "has id in params" do
        SimpleAction.last_params[:id].should eq 42
      end

      it "has value in params" do
        SimpleAction.last_params[:value].should eq 42
      end

      it "has time in params" do
        SimpleAction.last_params[:time].should eq Time.epoch(1506952232)
      end

      it "has kebab-param in params" do
        SimpleAction.last_params["kebab-param"].should eq "FOO"
      end
    end

    describe "testing certain content types" do
      context "JSON" do
        response = handle_request(SimpleAction, Req.new(
          method: "POST",
          resource: "/",
          body: {
            id:          42,
            float_value: 0.000000000001,
          }.to_json,
          headers: HTTP::Headers{
            "Content-Type" => "application/json",
          }
        ))

        it "properly parses float" do
          SimpleAction.last_params[:float_value].should eq 0.000000000001
        end
      end
    end

    context "with missing insignificant param" do
      response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42"))

      it "doesn't halt" do
        response.body.should eq "ok"
      end

      it "returns params" do
        SimpleAction.last_params[:id].should eq 42
      end
    end

    context "with missing significant params" do
      it "raises" do
        expect_raises(ParamNotFoundError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?value=42"))
        end
      end
    end

    context "with invalid params type" do
      it "raises" do
        expect_raises(InvalidParamTypeError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=foo"))
        end
      end

      it "raises" do
        expect_raises(InvalidParamTypeError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&value=foo"))
        end
      end
    end

    context "with invalid params" do
      it "raises" do
        expect_raises(InvalidParamError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=41"))
        end
      end
    end
  end
end
