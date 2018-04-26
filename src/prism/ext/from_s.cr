# :nodoc:
struct Float32
  def self.from_s(string)
    string.to_f32
  end
end

# :nodoc:
struct Float64
  def self.from_s(string)
    string.to_f64
  end
end

# :nodoc:
struct Int32
  def self.from_s(string)
    string.to_i32
  end
end

# :nodoc:
struct Int64
  def self.from_s(string)
    string.to_i64
  end
end

# :nodoc:
struct Time
  def self.from_s(string)
    epoch(string.to_i64)
  end
end

# :nodoc:
struct Time::Span
  def self.from_s(string)
    new(string.to_i64 * TicksPerSecond)
  end
end

# :nodoc:
class String
  def self.from_s(string)
    string
  end
end
