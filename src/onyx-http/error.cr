module Onyx::HTTP
  # A HTTP error which is expected to be rescued upon processing,
  # for example by `Middleware::Rescuer`, and then rendered by `Middleware::Renderer`.
  #
  # Define your own errors to handle **expected** situations:
  #
  # > In case of error, a plain text response status and body will be
  # > `404` and `"404 User not found with ID 42"` respectively.
  #
  # ```
  # class UserNotFound < Onyx::HTTP::Error(404)
  #   def initialize(@id : Int32)
  #     super("User not found with ID #{@id}")
  #   end
  #
  #   def payload
  #     {id: @id}
  #   end
  # end
  #
  # # Will return 404 erorr if a user isn't found by the ID
  # router.get "/users/:id" do |env|
  #   id = env.request.path_params["id"]?.to_i?
  #   raise UserNotFound.new(id) unless Models::User.find?(id)
  # end
  # ```
  class Error(Code) < Exception
    # The HTTP status code of this error.
    getter code : Int32 = Code

    # The error payload. Usually used by custom renderers, for example,
    # `Onyx::HTTP::Renderers::JSON` calls `error.payload.try &.to_json`.
    # Returns `nil` by default.
    def payload
    end
  end

  # This class exists so the compiler could detect the type at `error.code` call.
  private class NullError < Error(0)
  end
end
