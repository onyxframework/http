require "http/server/context"
require "./endpoint/*"

# A REST endpoint. `Action` and `Channel` include this module.
#
# A endpoint includes `.params` (see `Action.params` and `Channel.params`,
# they are identical) and `.errors` macros.
module Onyx::REST::Endpoint
  # The current HTTP::Server context.
  protected getter context : ::HTTP::Server::Context

  def initialize(@context : ::HTTP::Server::Context)
  end
end
