module Prism::Params
  class InvalidParamTypeError < Exception
    getter name
    getter expected_type

    MESSAGE_TEMPLATE = "Parameter \"%{name}\" is expected to be %{type}"

    def initialize(@name : String, @expected_type : String)
      super(MESSAGE_TEMPLATE % {
        name: @name,
        type: @expected_type,
      })
    end
  end

  class ParamNotFoundError < Exception
    getter name

    MESSAGE_TEMPLATE = "Parameter \"%{name}\" is missing"

    def initialize(@name : String)
      super(MESSAGE_TEMPLATE % {
        name: @name,
      })
    end
  end

  class InvalidParamError < Exception
    getter name, message

    MESSAGE_TEMPLATE = "Parameter \"%{name}\" %{message}"

    def initialize(@name : String, @message : String = "is invalid")
      super(MESSAGE_TEMPLATE % {
        name:    @name,
        message: @message,
      })
    end
  end
end
