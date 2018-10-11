require "../handlers/router"
require "../ext/http/server/response/view"
require "../ext/http/server/response/error"
require "./params"
require "./errors"

class Atom
  module Handlers
    class Router
      # Draw a route for *path* and *methods* calling *action*. See `Action`.
      #
      # ```
      # router = Atom::Handlers::Router.new do
      #   on "/foo", methods: %w(get post), MyAction
      # end
      # ```
      def on(path, methods : Array(String), action : Action.class)
        methods.map(&.downcase).each do |method|
          add("/" + method + path, ContextProc.new do |context|
            begin
              return_value = action.call(context)
              context.response.view = return_value if return_value.is_a?(Atom::View)
            rescue e : Params::Error
              context.response.error = e
            rescue e : Action::Error
              context.response.error = e
            end
          end.as(Node))
        end
      end

      {% for method in HTTP_METHODS %}
        # Draw a route for *path* with `{{method.upcase.id}}` calling *action*. See `Action`.
        #
        # ```
        # router = Atom::Handlers::Router.new do
        #   {{method.id}} "/bar", MyAction
        # end
        # ```
        def {{method.id}}(path, action : Action.class)
          on(path, [{{method}}], action)
        end
      {% end %}
    end
  end
end
