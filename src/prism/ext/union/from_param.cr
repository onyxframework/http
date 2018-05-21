struct Union(T)
  # Initialize from *param* value.
  #
  # If the value is overlapped by Union Types, returns `param.value.as(self)`.
  # Otherwise `.from_param` cast is attempted on each Union Type unless found suitable.
  def self.from_param(param : Prism::Params::AbstractParam)
    if param.value.is_a?(self)
      param.value.as(self)
    else
      ({{ T.map { |t| "(#{t}.from_param(param) rescue nil)" }.join(" || ").id }}).as(self)
    end
  end
end
