require "../spec_helper"
require "../../src/atom/action"

struct ActionWithErrors
  include Atom::Action

  errors do
    type Foo(404)
    type Bar(405), x : Int32, y : String = "default" do
      super("It's Bar!")
    end
  end

  def call
  end

  def raise_foo
    raise Foo.new
  end

  def raise_bar
    raise Bar.new(42)
  end

  describe self do
    it do
      begin
        self.new(dummy_context).raise_foo
      rescue e : ActionWithErrors::Foo
        e.code.should eq 404
        e.payload.should be_nil
        e.message.should be_nil
      end
    end

    it do
      begin
        self.new(dummy_context).raise_bar
      rescue e : ActionWithErrors::Bar
        e.code.should eq 405
        e.payload.should eq ({x: 42, y: "default"})
        e.message.should eq "It's Bar!"
      end
    end
  end
end
