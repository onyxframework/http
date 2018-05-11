require "../src/prism/ext/http/request/path_params"
require "../src/prism/params"

class SimpleAction
  include Prism::Params

  params do
    param :user, nilable: true do
      param :email, String, validate: {regex: /@/}
      param :password, String, validate: {size: (1..32)}
    end

    param :id, Int32?, validate: {min!: 0}
  end

  def self.call(context)
    params = parse_params(context)
  end
end

require "http/server"
alias Req = HTTP::Request

def new_context(request = Req.new("GET", "/"), response = HTTP::Server::Response.new(IO::Memory.new))
  HTTP::Server::Context.new(request, response)
end

require "benchmark"

puts "\nBegin benchmarking params..."
puts "Running single param benchmark...\n\n"

Benchmark.ips do |x|
  context = new_context(Req.new(method: "GET", resource: "/?id=42"))

  x.report "query" do
    SimpleAction.call(context)
  end

  context = new_context(Req.new("GET", "/42").tap do |r|
    r.path_params = {"id" => "42"}
  end)

  x.report "path" do
    SimpleAction.call(context)
  end

  context = new_context(Req.new("GET", "/", HTTP::Headers{"Content-Type" => "application/json"}, {"id" => 42}.to_json.to_s))

  x.report "json" do
    SimpleAction.call(context)
  end
end

puts "\nRunning nested params benchmark...\n\n"

Benchmark.ips do |x|
  context = new_context(Req.new(method: "GET", resource: "/?user[email]=foo@example.com&user[password]=qwerty"))

  x.report "query" do
    SimpleAction.call(context)
  end

  context = new_context(Req.new("GET", "/", HTTP::Headers{"Content-Type" => "application/json"}, {"user" => {"email" => "foo@example.com", "password" => "qwerty"}}.to_json.to_s))

  x.report "json" do
    SimpleAction.call(context)
  end
end

puts "\n✔️ Done benchmarking params"
