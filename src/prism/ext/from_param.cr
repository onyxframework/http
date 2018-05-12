struct Float32
  # Initialize from string *param*.
  #
  # ```
  # Float32.from_param("42.02") # => 42.02
  # ```
  def self.from_param(param : String)
    param.to_f32
  end
end

struct Float64
  # Initialize from string *param*.
  #
  # ```
  # Float64.from_param("42.02") # => 42.02_f64
  # ```
  def self.from_param(param : String)
    param.to_f64
  end
end

struct Int32
  # Initialize from string *param*.
  #
  # ```
  # Int32.from_param("1") # => 1
  # ```
  def self.from_param(param : String)
    param.to_i32
  end
end

struct Int64
  # Initialize from string *param*.
  #
  # ```
  # Int64.from_param("1") # => 1_i64
  # ```
  def self.from_param(param : String)
    param.to_i64
  end
end

struct Time
  # Initialize from string *param*. The param must represent number of milliseconds elapsed since the Unix epoch.
  #
  # ```
  # Time.from_param("1526120573870") # => 2018-05-12 10:22:53 UTC
  # ```
  def self.from_param(param : String)
    epoch_ms(param.to_i64)
  end
end

struct Time::Span
  # Initialize from string *param*. The param must represent a number of nanoseconds (1 billionth of second).
  #
  # ```
  # Time::Span.from_param("500") # => 00:00:00.000000500
  # ```
  def self.from_param(param : String)
    new(nanoseconds: param.to_i64)
  end
end

class String
  # Initialize from string *param*. It basically returns the param itself.
  #
  # ```
  # String.from_param("foo") # => "foo"
  # ```
  def self.from_param(param : String)
    param
  end
end
