# Temporary fix. See https://github.com/crystal-lang/crystal/issues/5286
abstract class JSON::Lexer
  private def consume_float(negative, integer, digits)
    append_number_char
    divisor = 1_u64
    char = next_char

    unless '0' <= char <= '9'
      unexpected_char
    end

    while '0' <= char <= '9'
      append_number_char
      integer *= 10
      integer += char - '0'
      divisor *= 10
      digits += 1
      char = next_char
    end
    float = integer.to_f64 / divisor

    if char == 'e' || char == 'E'
      consume_exponent(negative, float, digits)
    else
      @token.type = :FLOAT
      # If there's a chance of overflow, we parse the raw string
      if digits >= 18
        @token.float_value = number_string.to_f64
      else
        @token.float_value = negative ? -float : float
      end
      number_end
    end
  end
end
