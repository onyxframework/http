require "../../../../../error"

# An expected `HTTP::Params::Serializable` error.
class Onyx::REST::Errors::ParamsError < Onyx::REST::Error(400)
  # :nodoc:
  def initialize(message : String, @path : Array(String))
    super(message)
  end

  # Return `{path: @path}`, where `@path` is the path to the param
  # (e.g. `["foo", "bar"]` for `"foo[bar]=baz"` param).
  def payload
    {path: @path}
  end
end
