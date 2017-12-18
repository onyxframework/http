module Rest
  # This module allows to define callbacks.
  #
  # Example usage:
  #
  # ```
  # class MyClass
  #   include Callbacks
  #
  #   def my_call
  #     with_callbacks do
  #       puts "call"
  #     end
  #   end
  #
  #   before do
  #     puts "before"; true # If any of `before` callbacks returns falsey value, the call is aborted
  #   end
  #
  #   before do
  #     puts "another before"; true
  #   end
  #
  #   around do
  #     puts "begin around"
  #     yield
  #     puts "end around"
  #   end
  #
  #   around do
  #     puts "begin inner around"
  #     yield
  #     puts "end inner around"
  #   end
  #
  #   # After callbacks are always called despite of `around` return value
  #   after do
  #     puts "after"
  #   end
  #
  #   after do
  #     puts "will not be called" # Because previous definition returns nil
  #   end
  # end
  #
  # MyClass.new.my_call
  #
  # # => before
  # # => another before
  # # => begin around
  # # => begin inner around
  # # => call
  # # => end inner around
  # # => end around
  # # => after
  # ```
  module Callbacks
    macro included
      {% unless @type.has_method?(:before) %}
        def before
          true
        end
      {% end %}

      {% unless @type.has_method?(:around) %}
        def around(&block)
          yield; true
        end
      {% end %}

      {% unless @type.has_method?(:after) %}
        def after
          true
        end
      {% end %}
    end

    # Add before callback.
    # Should return truthy value, otherwise the whole callback chain is aborted.
    # Futher before callbacks are called later.
    #
    # ```
    # before do
    #   puts "before"; true
    # end
    # ```
    macro before(&block)
      def before
        if previous_def
          {{yield}}
        end
      end
    end

    # Add around callback. Further around callbacks are deeper in the stack.
    #
    # ```
    # around do
    #   puts "before call"
    #   yield
    #   puts "after call"
    # end
    # ```
    macro around(&block)
      def around(&block)
        previous_def do
          {{yield}}
        end
      end
    end

    # Add after callback.
    # Should return truthy value, otherwise other after callbacks are not called.
    # Futher after callbacks are called later.
    #
    # ```
    # after do
    #   puts "after"; true
    # end
    # ```
    macro after(&block)
      def after
        if previous_def
          {{yield}}
        end
      end
    end

    def with_callbacks(&block)
      before && around { yield } && after
    end
  end
end
