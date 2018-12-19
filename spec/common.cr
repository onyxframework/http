require "../src/onyx-rest"
require "../src/onyx-rest/ext/http-params-serializable"

class IAmACoffeepot < Onyx::REST::Error(419)
  def initialize
    super("I am a coffeepot ☕️")
  end
end

struct MyParams
  include HTTP::Params::Serializable
  getter foo : Int32
end
