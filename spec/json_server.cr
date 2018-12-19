require "./common"

class JSONServer
  def self.new
    logger = Logger.new(STDOUT, Logger::DEBUG)

    request_id = Onyx::REST::RequestID.new
    request_logger = Onyx::REST::Loggers::Standard.new(logger, severity: Logger::DEBUG)
    cors = Onyx::REST::CORS.new
    renderer = Onyx::REST::Renderers::JSON.new
    standard_rescuer = Onyx::REST::Rescuers::Standard.new(renderer, logger: logger)
    params_rescuer = HTTP::Params::Serializable::Rescuer.new(renderer)
    router = Onyx::REST::Router.new

    server = Onyx::REST::Server.new([request_id, request_logger, standard_rescuer, params_rescuer, router, renderer], logger: logger)

    router.draw do
      get "/" do
        {hello: "onyx"}.to_json
      end

      get "/error" do
        raise "Oops"
      end

      get "/coffee" do
        raise IAmACoffeepot.new
      end

      get "/params" do |env|
        params = MyParams.new(env.request.query.to_s)
        {foo: params.foo}.to_json
      end
    end

    server
  end
end
