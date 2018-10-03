# :nodoc:
module Prism::Params
  private class MacroParser
    @indent = 0
    @nilable = Hash(Int32, Bool).new

    def print_indent
      "  " * @indent
    end

    def print(calls)
      calls.each_line.each do |call|
        case call
        when /^\s*type\((?<name>\w+)(?<nilable>, nilable: true)?\) do$/
          puts print_indent + $~["name"] + ": {"
          @nilable[@indent] = true if $~["nilable"]?
          @indent += 1
        when /^\s*type\((\w+) : ([\w\| \?\(\):]+)\)$/
          puts print_indent + $~[1] + ": " + $~[2] + ","
        when /^\s*end$/
          @indent -= 1
          puts print_indent + "}#{" | ::Nil" if @nilable[@indent]?},"
          @nilable[@indent] = false
        else
          raise ArgumentError.new("Unsupported params definition syntax: `#{call}`")
        end
      end
    end
  end

  MacroParser.new.print(ARGV[0])
end
