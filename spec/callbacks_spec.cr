require "./spec_helper"
require "../src/rest/callbacks"

module Rest::CallbacksSpec
  class SimpleClass
    include Callbacks

    @buffer = [] of Int32
    getter buffer

    before do
      @buffer.push(1)
    end

    before do
      @buffer.push(2)
    end

    around do
      @buffer.push(3)
      yield
      @buffer.push(4); false # `false` should be ignored
    end

    around do
      @buffer.push(5)
      yield
      @buffer.push(6)
    end

    after do
      @buffer.push(7); false
    end

    after do
      @buffer.push(8) # Should not be called
    end

    def call
      with_callbacks do
        @buffer.push(9)
      end
    end
  end

  describe Rest::Callbacks do
    it do
      instance = SimpleClass.new
      instance.call
      instance.buffer.should eq [1, 2, 3, 5, 9, 6, 4, 7]
    end
  end
end
