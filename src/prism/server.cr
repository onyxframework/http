require "logger"
require "colorize"
require "http/server"
require "./ext/http/request/action"
require "./version"

module Prism
  # A simple TCP `HTTP::Server` wrapper relying on `HTTP::Request::Action`.
  #
  # Example usage:
  #
  # ```
  # require "prism"
  #
  # router = Prism::Router.new do
  #   get "/" do |env|
  #     env.response.print("Hello world!")
  #   end
  # end
  #
  # log_handler = Prism::LogHandler.new(Logger.new(STDOUT))
  #
  # server = Prism::Server.new([log_handler, router], "0.0.0.0", 5000)
  # server.listen
  #
  # #  INFO -- : Prism::Server v0.1.0 is listening on http://0.0.0.0:5000
  # #  INFO -- :     GET /? 200 61μs
  # #  INFO -- :     GET /foo? 404 166μs
  # #  INFO -- : Prism::Server is shutting down!
  # ```
  #
  # NOTE: You're not obligated to use `Prism::Server`, you can use standard `HTTP::Server` as well, just remember to handle `context.request.action`.
  class Server
    def initialize(
      handlers : Array(HTTP::Handler),
      @host = "0.0.0.0",
      @port = 5000,
      reuse_port = false,
      @logger = ::Logger.new(STDOUT)
    )
      @tcp_server = HTTP::Server.new(handlers) do |context|
        if action = context.request.action
          action.call(context)
        else
          context.response.status_code = 404
          context.response.print("Not Found: #{context.request.path}")
        end
      end

      @tcp_server.bind_tcp(@host, @port)
    end

    def listen
      @logger.info(
        "Prism::Server " +
        "v#{VERSION}".colorize(:light_gray).mode(:bold).to_s +
        " is listening on " +
        "http://#{@host}:#{@port}".colorize(:light_gray).mode(:bold).to_s
      )

      Signal::INT.trap do
        puts "\n"
        @logger.info("Prism::Server is shutting down!")
        exit
      end

      @tcp_server.listen
    end
  end
end
