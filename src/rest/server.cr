require "logger"
require "./ext/http/request/action"
require "./version"

module Rest
  # A simple and beautiful wrapper utilizing `Router`.
  #
  # ```
  # require "rest/router"
  # require "rest/logger"
  # require "rest/server"
  #
  # router = Rest::Router.new do |r|
  #   r.get "/" do |env|
  #     env.response.print("Hello world!")
  #   end
  # end
  #
  # logger = Rest::Logger.new(Logger.new(STDOUT))
  #
  # server = Rest::Server.new(handlers: [logger, router])
  # server.listen
  #
  # #  INFO -- :   Rest server v0.1.0 is up @ http://localhost:5000
  # #  INFO -- :    GET /? 200 61μs
  # #  INFO -- :   Rest server is going to take some rest ~(˘▾˘~)
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

    # :nodoc:
    COLORS = %i(red green yellow blue cyan)

    def listen
      color = COLORS.sample(1).first

      @logger.info(
        "Rest".rjust(6).colorize(color).mode(:bold).to_s +
        " server " +
        "v#{VERSION}".colorize(:light_gray).mode(:bold).to_s +
        " is up @ " +
        "http://#{@host}:#{@port}".colorize.mode(:bold).to_s
      )

      Signal::INT.trap do
        @logger.info(
          "Rest".rjust(6).colorize(color).mode(:bold).to_s +
          " server is going to take some rest ~(˘▾˘~)"
        )
        exit
      end

      super
    end
  end
end
