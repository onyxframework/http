struct Float32
  def self.from_s(string)
    string.to_f32
  end
end

struct Float64
  def self.from_s(string)
    string.to_f64
  end
end

struct Int32
  def self.from_s(string)
    string.to_i32
  end
end

struct Int64
  def self.from_s(string)
    string.to_i64
  end
end

struct Time
  def self.from_s(string)
    epoch(string.to_i64)
  end
end

struct Time::Span
  def self.from_s(string)
    new(string.to_i64 * TicksPerSecond)
  end
end

class String
  def self.from_s(string)
    string
  end
end
