require "../params_spec"

module Prism::Params::ValidationSpec
  class SimpleAction
    include Prism::Params

    params do
      param :id, Int32
      param :name, String, validate: {
        size:   (3..16),
        regex:  /\w+/,
        custom: ->(name : String) {
          error!(:name, "has reserved value") if %w(foo bar baz).includes?(name)
        },
      }
      param :age, Int32, nilable: true, validate: {min!: 17}
      param :height, Float64?, validate: {in: (0.5..2.5)}
      param :iq, Int32?, validate: {min: 100, max!: 200}
    end

    def self.call(context)
      begin
        params = parse_params(context)
        context.response.print("ok")
      rescue ex : InvalidParamTypeError | ParamNotFoundError | InvalidParamError
        context.response.print(ex.message)
      end
    end
  end

  macro assert_invalid_param(query, name, message)
    response = handle_request(SimpleAction, Req.new(method: "GET", resource: {{query}}))
    response.body.should eq "Parameter \"" + {{name}} + "\" " + {{message}}
  end

  describe "Prism::Params validation" do
    it "passes when valid" do
      response = handle_request(SimpleAction, Req.new(method: "GET", resource: "/?id=42&name=kek&age=18&height=1.0&iq=199"))
      response.body.should eq "ok"
    end

    describe "#id" do
      it "validates presence" do
        assert_invalid_param("?name=kek", "id", "is missing")
      end
    end

    describe "#name" do
      it "validates presence" do
        assert_invalid_param("?id=42", "name", "is missing")
      end

      it "validates size" do
        assert_invalid_param("?id=42&name=a", "name", "must have size in range of 3..16")
      end

      it "validates regex" do
        assert_invalid_param("?id=42&name=---", "name", "must match /w+/")
      end

      it "validates custom" do
        assert_invalid_param("?id=42&name=foo", "name", "has reserved value")
      end
    end

    describe "#age" do
      it "validates min!" do
        assert_invalid_param("?id=42&name=kek&age=17", "age", "must be greater than 17")
      end
    end

    describe "#height" do
      it "validates in" do
        assert_invalid_param("?id=42&name=kek&height=0.1", "height", "must be included in 0.5..2.5")
      end
    end

    describe "#iq" do
      it "validates min" do
        assert_invalid_param("?id=42&name=kek&iq=10", "iq", "must be greater or equal to 100")
      end

      it "validates max!" do
        assert_invalid_param("?id=42&name=kek&iq=200", "iq", "must be less than 200")
      end
    end
  end
end
