require "./silent"

module Onyx::HTTP::Middleware::Rescuer(T)
  class Error < Silent(Error)
  end
end
