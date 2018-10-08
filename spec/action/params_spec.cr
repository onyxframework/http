require "../spec_helper"
require "../../src/atom/action"

struct ActionWithParams
  include Atom::Action

  params do
    type id : Int32
    type name : String?
    type user do
      type email : String
      type active : Bool | Nil
    end
    type meta, nilable: true do
      type foo : Float32
    end
  end

  def call
    text("#{id}, #{name}, #{user.email}, #{user.active}, #{meta.not_nil!.foo}")
  end

  describe self do
    klass = self

    it do
      response = handle_request(self, Req.new("GET", "/?id=42&name=foo&user[email]=foo&user[active]=true&meta[foo]=17"))
      response.body.should eq "42, foo, foo, true, 17.0"
    end

    it "raises on missing param" do
      expect_raises ::Params::MissingError do
        handle_request(klass, Req.new("GET", "/?"))
      end
    end
  end
end
