module Prism::Params
  abstract class ParamError < Exception
    getter param

    def initialize(@param : AbstractParam)
      super(build_message)
    end

    def path
      param.path + [param.name]
    end

    abstract def build_message : String
  end

  # Raised when a param cannot be casted to the desired type.
  class InvalidParamTypeError < ParamError
    getter expected_type

    MESSAGE_TEMPLATE = "Parameter \"%{path}\" is expected to be %{expected} (given %{given})"

    def initialize(param : AbstractParam, @expected_type : String)
      super(param)
    end

    private def build_message
      MESSAGE_TEMPLATE % {
        path:     path.join(" > "),
        expected: expected_type,
        given:    param.value.inspect,
      }
    end
  end

  # Raised when a param is not present.
  class ParamNotFoundError < ParamError
    MESSAGE_TEMPLATE = "Parameter \"%{path}\" is missing"

    def initialize(param : AbstractParam)
      super(param)
    end

    private def build_message
      MESSAGE_TEMPLATE % {
        path: path.join(" > "),
      }
    end
  end

  # Raised when a param is invalid.
  class InvalidParamError < ParamError
    getter detail : String

    MESSAGE_TEMPLATE = "Parameter \"%{path}\" %{detail}"

    def initialize(param : AbstractParam, detail : String? = nil)
      @detail = detail || "is invalid"
      super(param)
    end

    private def build_message
      MESSAGE_TEMPLATE % {
        path:    path.join(" > "),
        detail: detail,
      }
    end
  end

  class ProcError < ParamError
    getter detail : String

    MESSAGE_TEMPLATE = "Failed to process parameter \"%{path}\": %{detail}"

    def initialize(param : AbstractParam, detail : String? = nil)
      @detail = detail || "no error message"
      super(param)
    end

    private def build_message
      MESSAGE_TEMPLATE % {
        path:   path,
        detail: detail,
      }
    end
  end
end
