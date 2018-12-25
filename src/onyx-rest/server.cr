require "http/server"

# The Onyx REST server. Basically it is just a wrapper around default `HTTP::Server`,
# which logs server start and stop events.
#
# ```
# server = Onyx::REST::Server.new(handlers, name: "My App Server")
# server.bind_tcp("0.0.0.0", 5000)
# server.listen
#
# # I [19:58:45.947] My App Server is listening at http://127.0.0.1:5000
# # I [19:58:48.479] My App Server is shutting down!
# ```
class Onyx::REST::Server < HTTP::Server
  # Initialize with an array of *handlers*.
  def initialize(
    handlers : Array,
    *,
    @name : String = "Onyx::REST::Server",
    @logger : Logger? = Logger.new(STDOUT),
    @logger_severity : Logger::Severity = Logger::INFO
  )
    super(HTTP::Server.build_middleware(handlers.map(&.as(HTTP::Handler))))
  end

  # Initialize with a single *handler*.
  def self.new(handler : HTTP::Handler, *args, **nargs)
    new([handler], *args, **nargs)
  end

  # Start listening for requests. Blocks the runtime, just like the vanilla `HTTP::Server`.
  def listen
    if logger = @logger
      io = IO::Memory.new
      io << "⬛".colorize(:green).mode(:bold) << " " << @name
      io << " is listening at ".colorize(:light_gray)
      io << @sockets.join(", ") { |s| format_address(s) }
      logger.log(@logger_severity, io.to_s)
    end

    Signal::INT.trap do
      puts "\n"

      if logger = @logger
        io = IO::Memory.new
        io << "⬛".colorize(:red).mode(:bold) << " " << @name
        io << " is shutting down!".colorize(:light_gray)
        logger.not_nil!.log(@logger_severity, io.to_s)
      end

      exit
    end

    super
  end

  protected def format_address(socket : Socket::Server)
    case socket
    when OpenSSL::SSL::Server then "https://#{socket.local_address}"
    when TCPServer            then "http://#{socket.local_address}"
    when UNIXServer           then "#{socket.path}"
    else                           "?"
    end
  end
end
