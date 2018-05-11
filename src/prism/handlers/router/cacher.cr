class Prism::Handlers::Router
  # Boost `Router` performance with cache!
  #
  # Example:
  #
  # ```
  # cacher = Prism::Handlers::Router::Cachers::Simple.new(10_000)
  # router = Prism::Handlers::Router.new(cacher) do
  #   # ...
  # end
  # ```
  abstract class Cacher
    abstract def find(tree, path)
  end
end
