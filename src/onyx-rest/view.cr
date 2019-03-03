# A reusable REST view. Views are usually rendered in `Renderers`. You are not required to
# use views in `Action`s, as you still have an access to the context, but it's a good
# practice to split business logic (actions) and rendering (views). You also can use views
# outside of actions, you'd just need to set `::HTTP::Server::Response#view` variable:
#
# ```
# struct UserView
#   include Onyx::REST::View
#
#   def initialize(@user : User)
#   end
#
#   json do
#     object do
#       field "id", @user.id
#       field "name", @user.name
#     end
#   end
# end
#
# router.get "/user/:id" do |env|
#   user = Onyx.query(User.where(id: env.request.path_params["id"].to_i))
#   env.response.view = UserView.new(user)
# end
#
# struct GetUser
#   include Onyx::REST::Action
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
# Do not forget to include a `Renderer` into your handlers stack to actually render views.
module Onyx::REST::View
  # Define a `#to_json` method with builder to be rendered with `Renderers::JSON`.
  #
  # All methods within the block are called on a JSON builder (it uses `with builder yield`
  # under the hood). See [`JSON::Builder` docs](https://crystal-lang.org/api/latest/JSON/Builder.html):
  #
  # ```
  # struct UserView
  #   include Onyx::REST::View
  #
  #   def initialize(@user : User)
  #   end
  #
  #   json do
  #     object do                  # builder.object do
  #       field "id", @user.id     # builder.field("id", @user.id)
  #       field "name", @user.name # ditto
  #     end
  #   end
  # end
  #
  # UserView.new(user).to_json # => {"id": 1, "name": "John"}
  # ```
  macro json(&block)
    def to_json
      io = IO::Memory.new
      builder = JSON::Builder.new(io)

      builder.document do
        to_json(builder)
      end

      io.to_s
    end

    def to_json(builder)
      build_json(builder) do
        {{yield}}
      end
    end

    def build_json(builder)
      with builder yield
    end
  end

  # Define a `#to_json` method with an arbitrary object to be rendered with `Renderers::JSON`.
  # This object will be invoked with `#to_json`.
  #
  # ```
  # struct UserView
  #   include Onyx::REST::View
  #
  #   def initialize(@user : User)
  #   end
  #
  #   # Would call `{id: @user.id, name: @user.name}.to_json`
  #   json({id: @user.id, name: @user.name})
  # end
  #
  # UserView.new(user).to_json # => {"id": 1, "name": "John"}
  # ```
  macro json(value)
    def to_json
      io = IO::Memory.new
      builder = JSON::Builder.new(io)

      builder.document do
        to_json(builder)
      end

      io.to_s
    end

    def to_json(builder)
      ({{value}}).to_json(builder)
    end
  end

  # Define a `#to_plain_text` method to be rendered with `Renderers::Plain`.
  #
  # ```
  # struct UserView
  #   include Onyx::REST::View
  #
  #   def initialize(@user : User)
  #   end
  #
  #   text do
  #     "id: #{@user.id}, name: #{@user.name}"
  #   end
  # end
  #
  # UserView.new(user).to_plain_text # => "id: 1, name: John"
  # ```
  macro text(&block)
    def to_plain_text
      io = IO::Memory.new
      to_plain_text(io)
      io.to_s
    end

    def to_plain_text(io)
      io << ({{yield}})
    end
  end

  # Define a `#to_plain_text` method with an arbitrary object to be rendered with `Renderers::Plain`.
  # This object will be invoked with `#to_s`.
  #
  # ```
  # struct UserView
  #   include Onyx::REST::View
  #
  #   def initialize(@user : User)
  #   end
  #
  #   text({id: @user.id, name: @user.name})
  # end
  #
  # UserView.new(user).to_plain_text # => "{id: 1, name: \"John\"}"
  # ```
  macro text(value)
    def to_plain_text
      io = IO::Memory.new
      to_plain_text(io)
      io.to_s
    end

    def to_plain_text(io)
      value = ({{value}})
      io << value
    end
  end

  # Define a `#render` method with a template path to be rendered with `Renderers::Template`.
  #
  # It uses [Kilt](https://github.com/jeromegn/kilt) under the hood. Basically,
  # to enable a template engine, you must add it as a dependency and require it.
  # [`ECR`](https://crystal-lang.org/api/latest/ECR.html) is required by default.
  #
  # Templates are embedded into the `#render` method, therefore they have an access to
  # the view's instance variables (`@user` in this case).
  # Example with [Slang](https://github.com/jeromegn/slang):
  #
  # ```slang
  # doctype html
  # html
  #   head
  #     title User
  #   body
  #     p User name = #{@user.name}
  # ```
  #
  # ```
  # require "kilt/slang"
  #
  # struct UserView
  #   include Onyx::REST::View
  #
  #   def initialize(@user : User)
  #   end
  #
  #   template("./templates/user.slang")
  # end
  #
  # UserView.new(user).render # => "<html>..."
  # ```
  macro template(template)
    def render(io)
      Kilt.embed("#{__DIR__}/#{{{template}}}", io)
    end
  end
end
