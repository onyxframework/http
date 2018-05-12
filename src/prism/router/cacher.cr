class Prism::Router
  # Boost `Router` performance with caching!
  #
  # Example:
  #
  # ```
  # cacher = Prism::Router::SimpleCacher.new(10_000)
  # router = Prism::Router.new(cacher) do
  #   # ...
  # end
  # ```
  abstract class Cacher
    abstract def find(tree, path) : Radix::Result(Node)
  end
end
