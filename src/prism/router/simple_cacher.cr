require "./cacher"

class Prism::Router
  # A straightforward cacher which has a limited capacity.
  #
  # Once the capacity is reached, the cache is partially cleared.
  class SimpleCacher < Cacher
    @cache = {} of String => Radix::Result(Node)

    # Create a new Simple Cacher with desired *capacity*. *cleanup_percentile* defines how much of the cache will be cleared on cleanup.
    def initialize(@capacity : Int32 | Int64, @cleanup_percentile = 0.2)
    end

    def find(tree, path)
      if cached_result = @cache[path]?
        return cached_result
      else
        result = tree.find(path)

        if result.found?
          if @cache.size >= @capacity
            @cache.delete_if { rand < @cleanup_percentile }
          end

          @cache[path] = result
        end

        return result
      end
    end

    # Force cache clearing.
    def clear
      @cache.clear
    end
  end
end
