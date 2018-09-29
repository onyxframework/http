require "./spec_helper"
require "../src/prism/params"

module Prism::Params::Specs
  class SimpleAction
    include Prism::Params

    params do
      type id : Int32
      type value : Int32?
      type time : Time?
      type float_value : Float64 | Nil
      type kebab_param : String | Null | Nil

      type nest1, nilable: true do
        type nest2 do
          type bar : Int32 | Null?
        end

        type foo : String?, proc: ->(p : String) { p.downcase }
        type array_param : Array(UInt8)?
      end

      type important : Array(String) | Null
      type boolean : Bool | Null?
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
      response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&value=42&time=1526120573870&kebab-param=null&nest1[nest2][bar]=null&nest1[foo]=BAR&nest1[arrayParam][]=2&nest1[arrayParam][]=3&important[]=foo&important[]=42&boolean=true"))

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
        SimpleAction.last_params[:time].should eq Time.epoch_ms(1526120573870_i64)
      end

      it "has kebab-param in params" do
        SimpleAction.last_params[:kebab_param].should be_a(Null)
      end

      it "has nest1 -> nest2 -> bar in params" do
        SimpleAction.last_params[:nest1]?.try &.[:nest2]?.try &.[:bar].should be_a(Null)
      end

      it "has nest1 -> foo in params" do
        SimpleAction.last_params[:nest1]?.try &.[:foo].should eq "BAR"
      end

      it "has nest1 -> arrayParam in params" do
        SimpleAction.last_params[:nest1]?.try &.[:array_param].should eq [2_u8, 3_u8]
      end

      it "has arrayParam in params" do
        SimpleAction.last_params[:important].should eq ["foo", "42"]
      end

      it "has boolean in params" do
        SimpleAction.last_params[:boolean].should eq true
      end
    end

    context "with missing insignificant param" do
      response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&important[]=foo&important[]=42&boolean=false"))

      it "doesn't halt" do
        response.body.should eq "ok"
      end

      it "returns params" do
        SimpleAction.last_params[:id].should eq 42
        SimpleAction.last_params[:important].should eq ["foo", "42"]
        SimpleAction.last_params[:boolean].should eq false
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
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=foo&important[]=foo"))
        end
      end

      it "raises" do
        expect_raises(InvalidParamTypeError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&important[]=foo&value=foo"))
        end
      end

      it "raises" do
        expect_raises(InvalidParamTypeError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&important[]=foo&nest1[arrayParam][]=foo"))
        end
      end

      it "raises" do
        expect_raises(InvalidParamTypeError) do
          response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&important[]=foo&boolean=unknown"))
        end
      end
    end

    describe "testing certain content types" do
      context "JSON" do
        request = Req.new(
          method: "POST",
          resource: "/",
          body: {
            id:         42,
            floatValue: 0.000000000001,
            kebabParam: "foo",
            nest1:      {
              nest2: {
                bar: nil,
              },
              arrayParam: [1, 2],
            },
            important: ["foo"],
            boolean:   false,
          }.to_json,
          headers: HTTP::Headers{
            "Content-Type" => "application/json",
          }
        )

        response = handle_request(SimpleAction, request)

        it "consumes request body" do
          (request.body.as(IO::Memory).pos == 0).should eq false
        end

        it "properly parses nullable param" do
          SimpleAction.last_params[:kebab_param].not_nil!.should eq "foo"
        end

        it "properly parses float" do
          SimpleAction.last_params[:float_value].should eq 0.000000000001
        end

        it "has nested params" do
          SimpleAction.last_params[:nest1]?.try &.[:nest2]?.try &.[:bar].should be_a(Null)
        end

        it "has array params" do
          SimpleAction.last_params[:important].should eq ["foo"]
        end

        it "has nested array params" do
          SimpleAction.last_params[:nest1]?.try &.[:array_param].should eq [1_u8, 2_u8]
        end

        it "has boolean param" do
          SimpleAction.last_params[:boolean].should eq false
        end
      end
    end
  end
end
