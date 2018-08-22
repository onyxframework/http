module Prism::Params
  # Raised when a param cannot be casted to the desired type.
  class InvalidParamTypeError < Exception
    getter param, expected_type

    MESSAGE_TEMPLATE = "Parameter \"%{path}\" is expected to be %{expected} (given %{given})"

    def initialize(@param : AbstractParam, @expected_type : String)
      path = @param.path.empty? ? @param.name : ((@param.path + [@param.name]).join(" > "))

      super(MESSAGE_TEMPLATE % {
        path:     path,
        expected: @expected_type,
        given:    @param.value.inspect,
      })
    end
  end

  # Raised when a param is not present.
  class ParamNotFoundError < Exception
    getter param

    MESSAGE_TEMPLATE = "Parameter \"%{path}\" is missing"

    def initialize(@param : AbstractParam)
      path = @param.path.empty? ? @param.name : ((@param.path + [@param.name]).join(" > "))

      super(MESSAGE_TEMPLATE % {
        path: path,
      })
    end
  end

  # Raised when a param is invalid.
  class InvalidParamError < Exception
    getter param, message

    MESSAGE_TEMPLATE = "Parameter \"%{path}\" %{message}"

    def initialize(@param : AbstractParam, @message : String? = nil)
      @message ||= "is invalid"

      path = @param.path.empty? ? @param.name : ((@param.path + [@param.name]).join(" > "))

      super(MESSAGE_TEMPLATE % {
        path:    path,
        message: @message,
      })
    end
  end

  class ProcError < Exception
    getter param, message

    MESSAGE_TEMPLATE = "Failed to process parameter \"%{path}\": %{message}"

    def initialize(@param : AbstractParam, @message : String? = nil)
      @message ||= "no error message"

      path = @param.path.empty? ? @param.name : ((@param.path + [@param.name]).join(" > "))

      super(MESSAGE_TEMPLATE % {
        path:    path,
        message: @message,
      })
    end
  end
end
