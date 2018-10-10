require "./spec_helper"
require "../src/atom/action"

struct BodyAction
  include Atom::Action

  class_property last_body : String? = nil

  def call
    @@last_body = body
  end

  describe self do
    response = handle_request(self, Req.new("GET", "/", body: "foo"))

    it do
      self.last_body.should eq "foo"
    end
  end
end

struct HeaderAction
  include Atom::Action

  def call
    header("Custom", "42")
  end

  describe self do
    response = handle_request(self)

    it do
      response.headers["Custom"].should eq "42"
    end
  end
end

struct RedirectAction
  include Atom::Action

  def call
    redirect(URI.parse("https://github.com/vladfaust/prism"), 301)
  end

  describe self do
    response = handle_request(self)

    it do
      response.headers["Location"].should eq "https://github.com/vladfaust/prism"
      response.status_code.should eq 301
    end
  end
end
