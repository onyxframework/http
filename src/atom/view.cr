require "./ext/http/server/response/view"

class Atom
  # Include this module to mark an including object as a View. It's likely to be handled
  # by a custom Hanlder or within Server block.
  module View
  end
end
