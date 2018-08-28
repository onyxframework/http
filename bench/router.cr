require "../src/prism"

RESPONSE = HTTP::Server::Response.new(IO::Memory.new)

static_path_request = HTTP::Server::Context.new(HTTP::Request.new("GET", "/bar"), RESPONSE)

# Paths are likely to never repeat
def random_path_request
  HTTP::Server::Context.new(HTTP::Request.new("GET", "/foo/#{rand}"), RESPONSE)
end

DYNAMIC_ROUTES_NUMBER = 10_000

# One of known paths
def dynamic_path_request
  HTTP::Server::Context.new(HTTP::Request.new("GET", "/foo/#{rand(DYNAMIC_ROUTES_NUMBER)}"), RESPONSE)
end

router = Prism::Router.new do
  get "/foo/:number" do |env|
  end

  get "/bar" do |env|
  end
end

require "benchmark"

Benchmark.ips do |x|
  x.report("with static path") do
    router.call(static_path_request)
  end

  x.report("with dynamic paths") do
    router.call(dynamic_path_request)
  end

  x.report("with random paths") do
    router.call(random_path_request)
  end
end
