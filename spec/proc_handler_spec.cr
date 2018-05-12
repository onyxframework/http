require "./spec_helper"
require "./../src/prism/proc_handler"

class Prism::ProcHandler
  def call_next(context)
    context.response.print("next")
  end
end

describe Prism::ProcHandler do
  handler = Prism::ProcHandler.new do |handler, context|
    if context.request.query_params.to_h["pass"]? == "true"
      handler.call_next(context)
    end
  end

  it do
    response = handle_request(handler)
  end

  context "when pass" do
    response = handle_request(handler, Req.new("GET", "/?pass=true"))

    it "calls next" do
      response.body.should eq "next"
    end
  end

  context "when not pass" do
    response = handle_request(handler, Req.new("GET", "/?pass=false"))

    it "calls next" do
      response.body.empty?.should be_true
    end
  end
end
