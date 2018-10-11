require "http/server/context"
require "./action/*"

class Atom
  # A callable HTTP action with [Params](https://github.com/vladfaust/params.cr) included.
  #
  # An Action itself isn't responsible for rendering. It *should* return an `Atom::View` instance,
  # and that view *should* be rendered in future handlers.
  #
  # Actions have special `.params` definition syntax, it's basically a convenient wrapper
  # over default NamedTuple syntax of [Params](https://github.com/vladfaust/params.cr).
  #
  # Action errors are to be defined in `.errors` block.
  #
  # ```
  # struct Actions::GetUser
  #   include Atom::Action
  #
  #   params do
  #     type id : Int32
  #   end
  #
  #   errors do
  #     type UserNotFound(404), id : Int32
  #   end
  #
  #   def call
  #     user = User[params.id]
  #     raise UserNotFound.new(params.id) unless user
  #     return Views::User.new(user)
  #   end
  # end
  #
  # Actions::GetUser.call(env) # => Views::User instance, if not raised Params::Error or UserNotFound
  # ```
  #
  # Router example:
  #
  # ```
  # router = Atom::Handlers::Router.new do
  #   get "/", Actions::GetUser
  #   # Equivalent of
  #   get "/" do |context|
  #     begin
  #       return_value = Actions::GetUser.call(context)
  #       context.response.view = return_value if return_value.is_a?(Atom::View)
  #     rescue e : Params::Error | Action::Error
  #       context.response.error = e
  #     end
  #   end
  # end
  # ```
  module Action
    # Where all the action takes place.
    abstract def call

    macro included
      # Initialize and invoke `#call`.
      def self.call(context : HTTP::Server::Context)
        new(context).call
      end

      # Will **not** raise on exceed when reading from body in the `#call` method, however could raise upon `.params` parsing.
      class_getter max_body_size : UInt64 = UInt64.new(8 * 1024 ** 2)

      # You can change `.max_body_size` per action basis.
      #
      # ```
      # struct MyAction
      #   include Atom::Action
      #   max_body_size = 1 * 1024 ** 3 # 1 GB
      # end
      # ```
      protected class_setter max_body_size

      # Change to `true` to preserve body upon params parsing.
      # Has effect only in cases when params are read from body.
      # Slightly decreases performance due to IO copying.
      class_getter preserve_body : Bool = false

      # You can change `.preserve_body` per action basis.
      #
      # ```
      # struct MyAction
      #   include Atom::Action
      #   preserve_body = true
      # end
      # ```
      protected class_setter preserve_body
    end

    @body : String?

    # Lazy string version of request body (read `.max_body_size` bytes on the first call).
    #
    # NOTE: Will be `nil` if `.preserve_body` is set to `false` and read on params parsing.
    #
    # ```
    # # Action A
    # def call
    #   body                 # => "foo"
    #   context.request.body # => nil
    # end
    #
    # # Action B
    # def call
    #   context.request.body # => "foo"
    #   body                 # => likely to be nil, because already read above
    # end
    #
    # # Action C
    # params do
    #   type foo : String
    # end
    #
    # preserve_body = false
    #
    # def call
    #   body # => nil if request type was JSON or form etc.
    # end
    #
    # # Action D
    # params do
    #   type foo : String
    # end
    #
    # preserve_body = true
    #
    # def call
    #   body # => "bar" even after params parsing
    # end
    # ```
    protected def body
      @body ||= context.request.body.try &.gets(limit: self.class.max_body_size)
    end

    # Current HTTP::Server context.
    protected getter context : HTTP::Server::Context

    def initialize(@context : HTTP::Server::Context)
    end

    # Set HTTP status code.
    #
    # ```
    # def call
    #   status(400)
    # end
    # ```
    protected def status(status : Int32)
      context.response.status_code = status
    end

    # Set HTTP header.
    #
    # ```
    # def call
    #   header("Content-Type", "application/json")
    # end
    # ```
    protected def header(name, value)
      context.response.headers[name] = value
    end

    # Set response status code to *code* and "Location" header to *location*.
    #
    # Does **not** interrupt the call.
    #
    # ```
    # def call
    #   redirect("https://google.com")
    #   text("will be called")
    # end
    # ```
    protected def redirect(location : String | URI, code = 302)
      status(code)
      header("Location", location.to_s)
    end
  end
end
