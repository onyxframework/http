class Exception
  # The status message for this error. Returns its class name decorated as
  # an HTTP status message, for example `"User Not Found"` for
  # `MyEndpoint::UserNotFound` error.
  def status_message
    {{@type.name.split("::").last.underscore.split("_").map(&.capitalize).join(" ")}}
  end
end
