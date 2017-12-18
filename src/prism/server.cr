require "logger"
require "./ext/http/request/action"
require "./version"

module Prism
  # A simple and beautiful wrapper utilizing `Router`.
  #
  # ```
  # require "prism/router"
  # require "prism/logger"
  # require "prism/server"
  #
  # router = Prism::Router.new do |r|
  #   r.get "/" do |env|
  #     env.response.print("Hello world!")
  #   end
  # end
  #
  # logger = Prism::Logger.new(Logger.new(STDOUT))
  #
  # server = Prism::Server.new(handlers: [logger, router])
  # server.listen
  #
  # #  INFO -- :   Prism server v0.1.0 is listening on http://localhost:5000...
  # #  INFO -- :     GET /? 200 61μs
  # #  INFO -- :   Prism server is shutting down!
  # ```
  class Server < HTTP::Server
    def initialize(@host : String = "0.0.0.0", @port : Int32 = 5000, handlers : Array(HTTP::Handler)? = nil, @logger = ::Logger.new(STDOUT))
      super(host, port, handlers) do |context|
        if action = context.request.action
          action.call(context)
        else
          context.response.status_code = 404
          context.response.print("Not found: #{context.request.path}")
        end
      end
    end

    def listen
      @logger.info(
        "".rjust(2) +
        self.class.logo +
        " server " +
        "v#{VERSION}".colorize(:light_gray).mode(:bold).to_s +
        " is listening on " +
        "http://#{@host}:#{@port}".colorize(:light_gray).mode(:bold).to_s +
        "..."
      )

      Signal::INT.trap do
        @logger.info(
          "".rjust(2) +
          self.class.logo +
          " server is shutting down!"
        )
        exit
      end

      super
    end

    def self.logo
      "P".colorize(:light_red).mode(:bold).to_s +
        "r".colorize(:light_yellow).mode(:bold).to_s +
        "i".colorize(:light_green).mode(:bold).to_s +
        "s".colorize(:light_cyan).mode(:bold).to_s +
        "m".colorize(:light_blue).mode(:bold).to_s
    end
  end
end
