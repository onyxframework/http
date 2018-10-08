require "http/server/handler"
require "logger"
require "colorize"
require "time_format"

module Atom::Handlers
  # Debugs requests colorfully into specified *logger*.
  #
  # ```
  # logger = Atom::Handlers::RequestLogger.new(Logger.new(STDOUT).tap &.level=(Logger::DEBUG))
  #
  # #  DEBUG -- :     GET /users 200 102μs
  # #  DEBUG -- :     GET /favicon.ico 404 52μs
  # #  DEBUG -- :    POST /users 201 3.74ms
  # ```
  class RequestLogger
    include HTTP::Handler

    WS_COLOR = :cyan

    def initialize(@logger : Logger)
    end

    def call(context)
      if @logger.level > Logger::DEBUG
        return call_next(context)
      else
        websocket = context.request.headers.includes_word?("Upgrade", "Websocket")

        if websocket
          method = "WS".rjust(7).colorize(WS_COLOR).mode(:bold)
          resource = context.request.resource.colorize(WS_COLOR)
          progess = "pending".colorize(:dark_gray)
          @logger.debug("#{method} #{resource} #{progess}")
        end

        elapsed = Time.measure do
          call_next(context)
        end

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

        @logger.debug("#{method} #{resource} #{status_code} #{TimeFormat.auto(elapsed).colorize(:dark_gray)}")
      end
    end
  end
end
