require "http/server/handler"
require "logger"
require "colorize"
require "time_format"

module Prism
  # `HTTP::Handler` which debugs requests colorfully into specified *logger*.
  #
  # ```
  # logger = Prism::LogHandler.new(Logger.new(STDOUT).tap { |l| l.level = Logger::DEBUG })
  #
  # #  DEBUG -- :     GET /users 200 102μs
  # #  DEBUG -- :     GET /favicon.ico 404 52μs
  # #  DEBUG -- :    POST /users 201 3.74ms
  # ```
  class LogHandler
    include HTTP::Handler

    WS_COLOR = :cyan

    def initialize(@logger : ::Logger)
    end

    def call(context)
      time = Time.now

      websocket = context.request.headers.includes_word?("Upgrade", "Websocket")

      if websocket
        method = "WS".rjust(7).colorize(WS_COLOR).mode(:bold)
        resource = context.request.resource.colorize(WS_COLOR)
        progess = "pending".colorize(:dark_gray)
        @logger.debug("#{method} #{resource} #{progess}")
      end

      begin
        call_next(context)
      ensure
        time = TimeFormat.auto(Time.now - time).colorize(:dark_gray)

        color = :red
        case context.response.status_code
        when 100..199
          color = :cyan
        when 200..299
          color = :green
        when 300..399
          color = :yellow
        end

        method = (websocket ? "WS" : context.request.method).rjust(7).colorize(color).mode(:bold)
        resource = context.request.resource.colorize(color)
        status_code = context.response.status_code.colorize(color).mode(:bold)

        @logger.debug("#{method} #{resource} #{status_code} #{time}")
      end
    end
  end
end
