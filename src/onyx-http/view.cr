require "kilt"
require "json"
require "xml"

# A reusable HTTP view.
#
# Views are usually rendered by the `Middleware::Renderer` invoking the `#render` method.
# You can use views either in raw endpoint procs or within `Endpoint#call`.
#
# ```
# struct UserView
#   include Onyx::HTTP::View
#
#   def initialize(@user : User)
#   end
#
#   def render(context)
#     context.response.content_type = "text/plain"
#     context.response << "id: #{@user.id}, name: #{@user.name}"
#   end
# end
#
# router.get "/user/:id" do |env|
#   user = Onyx.query(User.where(id: env.request.path_params["id"].to_i))
#
#   env.response.view = UserView.new(user)
#   # or just return it
#   UserView.new(user)
# end
#
# struct GetUser
#   include Onyx::HTTP::Endpoint
#
#   params do
#     path do
#       type id : Int32
#     end
#   end
#
#   def call
#     user = Onyx.query(User.where(id: params.path.id))
#     return UserView.new(user)
#   end
# end
# ```
#
# Apart from directly implementing the `#render` method, you can use the convenient macros:
#
# * `.text` to render the view as a text with `text/plain` content type by default
# * `.json` to render the view as a JSON with `application/json` content type by default
# * `.xml` to render the view as XML with `application/xml` content type by default
# * `.template` to render the view as a generic template (powered by [Kilt](https://github.com/jeromegn/kilt))
# with `text/html` content type by default
#
# If you have only one macro of these three called in a view, then the request's `"Accept"`
# header will be ignored and the view will always be rendered as specified:
#
# ```
# # Will always be rendered as `{"foo":@foo}`
# # with "Content-Type" set to `"application/json"`.
# struct JSONView
#   include Onyx::HTTP::View
#
#   def initialize(@foo : String)
#   end
#
#   json foo: @foo
# end
# ```
#
# Otherwise, if you have multiple macros called, then the request's `"Accept"` header is
# considered and the rendering is determined by it. However, if the `"Accept"` header
# is absent or equals to `"*/*"`, then the **latter** macro takes precendence:
#
# ```
# # If `Accept` header has `application/json` entry with
# # enough q-factor, then the JSON view would be rendered.
# # Otherwise the same check will be made for `text/html` entry.
# # If none succeeded, plain text is rendered then.
# struct MultiView
#   include Onyx::HTTP::View
#
#   def initialize(@foo : String)
#   end
#
#   json foo: @foo
#   template "./multi_view.html.ecr"
#   text "foo: #{@foo}"
# end
# ```
#
# You can define multiple renderers of the same type, just alter the arguments.
# The *accept* argument is what defines the behaviour (it is stored as hash internally,
# that's why the latter takes precendence when `"Accept"` header is `"*/*"`):
#
# ```
# struct TheView
#   include Onyx::HTTP::View
#
#   template("./view.html.ecr")
#   template("./view.rss.ecr", content_type: "text/rss", accept: {"text/rss"})
# end
# ```
module Onyx::HTTP::View
  abstract def render(context : ::HTTP::Server::Context)

  # Add plain text rendering to this view. It is expanded like this:
  #
  # ```
  # def render_to_plain(io : IO)
  #   io << ({{value}})
  # end
  # ```
  macro text(value, content_type = "text/plain", accept = {"text/plain"})
    define_type_renderer(render_to_{{content_type.split("/").map { |s| s.underscore.gsub(/-/, "_") }.join("_").id}}, {{content_type}}, {{accept}}) do
      io << ({{value}})
    end
  end

  # Add template rendering to this view. It is expanded like this:
  #
  # ```
  # def render_to_html(io : IO)
  #   Kilt.embed("#{__DIR__}/#{{{template}}}", io)
  # end
  # ```
  macro template(template, content_type = "text/html", accept = {"text/html"})
    define_type_renderer(render_to_{{content_type.split("/").map { |s| s.underscore.gsub(/-/, "_") }.join("_").id}}, {{content_type}}, {{accept}}) do
      Kilt.embed("#{__DIR__}/#{{{template}}}", io)
    end
  end

  # Add JSON rendering to this view. It is expanded to this:
  #
  # ```
  # def render_to_json(io : IO)
  #   ({{object}}).to_json(io)
  # end
  #
  # def to_json(builder : JSON::Builder)
  #   ({{object}}).to_json(builder)
  # end
  # ```
  macro json(object, content_type = "application/json", accept = {"application/json"}, &block)
    {% unless @type.methods.find { |m| m.name.stringify == "to_json" } %}
      def to_json(io : IO)
        ({{object}}).to_json(io)
      end

      def to_json(builder : JSON::Builder)
        ({{object}}).to_json(builder)
      end
    {% end %}

    define_type_renderer(render_to_{{content_type.split("/").map { |s| s.underscore.gsub(/-/, "_") }.join("_").id}}, {{content_type}}, {{accept}}) do
      {% if block %}
        {{object}} do |{{block.args.join(",").id}}|
          {{block.body}}
        end.to_json(io)
      {% else %}
        ({{object}}).to_json(io)
      {% end %}
    end
  end

  # Add JSON rendering with builder to this view.
  #
  # ```
  # struct TestView
  #   include Onyx::HTTP::View
  #
  #   def initialize(@foo : String, @bar : Int32? = nil)
  #   end
  #
  #   json do
  #     object do
  #       field "foo", @foo
  #       field "bar", @bar
  #     end
  #   end
  # end
  # ```
  macro json(content_type = "application/json", accept = {"application/json"}, &block)
    {% unless @type.methods.find { |m| m.name.stringify == "to_json" } %}
      def build_json(builder, &block)
        with builder yield
      end

      def to_json(io : IO)
        builder = JSON::Builder.new(io)

        builder.document do
          build_json(builder) do
            {{yield.id}}
          end
        end
      end

      def to_json(builder : JSON::Builder)
        build_json(builder) do
          {{yield.id}}
        end
      end
    {% end %}

    define_type_renderer(render_to_{{content_type.split("/").map { |s| s.underscore.gsub(/-/, "_") }.join("_").id}}, {{content_type}}, {{accept}}) do
      to_json(io)
    end
  end

  # Add JSON rendering to this view. It is expanded like this:
  #
  # ```
  # def to_application_json(io)
  #   ({{object}}).to_json(io)
  # end
  # ```
  macro json(content_type = "application/json", accept = {"application/json"}, **object)
    json({{object}})
  end

  # Add XML rendering with builder to this view.
  # See [XML::Builder](https://crystal-lang.org/api/latest/XML/Builder.html) for methods.
  #
  # ```
  # struct TestView
  #   include Onyx::HTTP::View
  #
  #   def initialize(@foo : String, @bar : Int32? = nil)
  #   end
  #
  #   xml do
  #     element("foo", @foo) do
  #       attribute("bar", @bar)
  #     end
  #   end
  # end
  # ```
  macro xml(content_type = "application/xml", accept = {"application/xml"}, &block)
    def build_xml(builder, &block)
      with builder yield
    end

    def to_xml(io : IO)
      builder = XML::Builder.new(io)

      builder.document do
        build_xml(builder) do
          {{yield.id}}
        end
      end
    end

    def to_xml(builder : XML::Builder)
      build_xml(builder) do
        {{yield.id}}
      end
    end

    define_type_renderer(render_to_{{content_type.split("/").map { |s| s.underscore.gsub(/-/, "_") }.join("_").id}}, {{content_type}}, {{accept}}) do
      to_xml(io)
    end
  end

  private macro define_proc_based_render
    @@render_hash = Hash(String, Proc(::HTTP::Server::Context, self, Nil)).new

    def render(context : ::HTTP::Server::Context)
      if accept = context.request.accept
        rendered = false

        accept.each do |a|
          if proc = @@render_hash[a.media_type]?
            rendered = true
            break proc.call(context, self)
          end
        end

        unless rendered
          if proc = @@render_hash["*/*"]?
            proc.call(context, self)
          else
            raise "BUG: #{self.class} cannot be rendered"
          end
        end
      elsif proc = @@render_hash["*/*"]?
        proc.call(context, self)
      else
        raise "BUG: #{self.class} cannot be rendered"
      end
    end
  end

  private macro define_type_renderer(method, content_type, accept, &block)
    {% if @type.has_method?(method.id.stringify) %}
      {% raise "Already defined `#{method.id}` method for this View" %}
    {% end %}

    {% unless @type.methods.find { |d| d.name == "render" && d.args.size > 0 && d.args.first.restriction == ::HTTP::Server::Context } %}
      define_proc_based_render
    {% end %}

    def {{method.id}}(io : IO)
      {{yield.id}}
    end

    proc = ->(context : ::HTTP::Server::Context, view : self) {
      context.response.content_type = {{content_type}}
      view.{{method.id}}(context.response)
    }

    ({{accept}}.to_a << "*/*").each do |media_type|
      @@render_hash[media_type] = proc
    end
  end
end
