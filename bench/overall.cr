require "../src/prism"

struct SimpleAction < Prism::Action
  def call
    text("hello world!")
  end
end

struct ParamsAction < Prism::Action
  include Params

  params do
    param :foo, String
  end

  def call
    text(params[:foo])
  end
end

struct NestedParamsAction < Prism::Action
  include Params

  params do
    param :user_id, Int32
    param :settings do
      param :email, String?
      param :password, String?, validate: {size: (0..32)}
    end
  end

  def call
    text("update user #{params[:user_id]}")
  end
end

cacher = Prism::Router::SimpleCacher.new(4)
router = Prism::Router.new(cacher) do
  get "/"

  get "/simple" do |env|
    SimpleAction.call(env)
  end

  get "/foo" do |env|
    ParamsAction.call(env)
  end

  put "/users/:user_id/update" do |env|
    NestedParamsAction.call(env)
  end
end

non_cached_router = Prism::Router.new do
  get "/"
  get "/simple", SimpleAction
  get "/foo", ParamsAction
  put "/users/:user_id/update", NestedParamsAction
end

server = uninitialized Prism::Server

spawn do
  server = Prism::Server.new(port: 5000, handlers: [router])
  server.listen(true)
end

sleep 2

require "http/client"

client = HTTP::Client.new("localhost", 5000)

require "benchmark"

puts "\nBegin overall benchmarking..."
puts "Running with cached router...\n\n"

Benchmark.ips do |x|
  x.report "empty action" { client.get "/" }
  x.report "single param action" { client.get "/?foo=bar" }
  x.report "nested params action" { client.get "/users/42/update" }
end

router.cacher = nil

puts "\nRunning with non-cached router...\n\n"

Benchmark.ips do |x|
  x.report "empty action w/o caching" { client.get "/" }
  x.report "single param action w/o caching" { client.get "/?foo=bar" }
  x.report "nested params action w/o caching" { client.get "/users/42/update" }
end

puts "\n✔️ Done overall benchmarking"
