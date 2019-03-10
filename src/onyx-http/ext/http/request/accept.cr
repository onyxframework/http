require "mime"

class HTTP::Request
  @accept : Array(MIME::MediaType)? = nil

  # An lazy array of `MIME::MediaType` this request accepts
  # determined by the `"Accept"` header or nil if it is empty.
  # The array is sorted by the [q-factor](https://developer.mozilla.org/en-US/docs/Glossary/quality_values).
  def accept : Array(MIME::MediaType) | Nil
    @accept ||= (
      if header = headers["Accept"]?
        header.split(",").map { |a| MIME::MediaType.parse(a) }.sort do |a, b|
          (b["q"]?.try &.to_f || 1.0) <=> (a["q"]?.try &.to_f || 1.0)
        end
      end
    )
  end
end
