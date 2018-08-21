require "../src/prism"

struct SimpleAction
  include Prism::Action

  def call
    text("hello world!")
  end
end

struct ParamsAction
  include Prism::Action
  include Prism::Action::Params

  params do
    type foo : String
  end

  def call
    text(params[:foo])
  end
end

struct NestedParamsAction
  include Prism::Action
  include Prism::Action::Params

  params do
    type user_id : Int32
    type settings do
      type email : String?
      type password : String?, validate: {size: (0..32)}
    end
  end

  def call
    text("update user #{params[:user_id]}")
  end
end

cacher = Prism::Router::SimpleCacher.new(4)
router = Prism::Router.new(cacher) do
  get "/"
  get "/simple", SimpleAction
  get "/foo", ParamsAction
  put "/users/:user_id/update", NestedParamsAction
end

server = uninitialized Prism::Server

spawn do
  server = Prism::Server.new([router])
  server.bind_tcp(5000, reuse_port: true)
  server.listen
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
