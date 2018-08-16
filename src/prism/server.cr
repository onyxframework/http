require "logger"
require "colorize"
require "http/server"
require "./ext/http/request/action"

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
  # server = Prism::Server.new([log_handler, router])
  # server.bind_tcp(5000)
  # server.listen
  #
  # #  INFO -- : Prism::Server is listening on http://localhost:5000
  # #  INFO -- :     GET /? 200 61μs
  # #  INFO -- :     GET /foo? 404 166μs
  # #  INFO -- : Prism::Server is shutting down!
  # ```
  #
  # NOTE: You're not obligated to use `Prism::Server`, you can use standard `HTTP::Server` as well, just remember to handle `context.request.action`.
  class Server
    def initialize(
      handlers : Array(HTTP::Handler),
      @logger = ::Logger.new(STDOUT)
    )
      @server = HTTP::Server.new(handlers) do |context|
        if action = context.request.action
          action.call(context)
        else
          context.response.status_code = 404
          context.response.print("Not Found: #{context.request.path}")
        end
      end
    end

    def listen
      # It's simpler than handling "not binded" case here
      @logger.info(
        "Prism::Server is listening on " +
        "http://#{addresses.first}".colorize(:light_gray).mode(:bold).to_s +
        "..."
      ) if addresses.any?

      Signal::INT.trap do
        puts "\n"
        @logger.info("Prism::Server is shutting down!")
        exit
      end

      @server.listen
    end

    forward_missing_to @server
  end
end
