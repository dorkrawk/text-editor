require "io/console"

class Editor
  def initialize
    lines = File.readlines("test_file.txt").map do |line|
      line.sub(/\n$/, "")
    end
    @buffer = Buffer.new(lines)
    @cursor = Cursor.new
    @history = []
  end

  def run
    IO.console.raw do
      loop do
        render
        handle_input
      end
    end
  rescue
    50.times { puts }
    raise
  end

  def render
    ANSI.clear_screen
    ANSI.move_cursor(0,0)
    @buffer.render
    ANSI.move_cursor(@cursor.row, @cursor.col)
  end

  def handle_input
    char = $stdin.getc
    if char == "\e"
      char << $stdin.read_nonblock(3) rescue nil
      char << $stdin.read_nonblock(2) rescue nil
    end
    case char
    when "\C-q" then exit(0)
    when "\e[A" then @cursor = @cursor.up(@buffer)
    when "\e[B" then @cursor = @cursor.down(@buffer)
    when "\e[D" then @cursor = @cursor.left(@buffer)
    when "\e[C" then @cursor = @cursor.right(@buffer)
    when "\e" then @buffer = Buffer.new(["bad"])
    when "\C-u" then restore_snapshot
    when "\r"
      save_snapshot
      @buffer = @buffer.split_line(@cursor.row, @cursor.col)
      @cursor = Cursor.new(@cursor.row + 1, 0)
    when 127.chr
      if @cursor.col > 0
        save_snapshot
        @buffer = @buffer.delete(@cursor.row, @cursor.col - 1)
        @cursor = @cursor.left(@buffer)
      end
    else
      save_snapshot
      @buffer = @buffer.insert(char, @cursor.row, @cursor.col)
      @cursor = @cursor.right(@buffer)
    end
  end

  def save_snapshot
    @history << [@buffer, @cursor]
  end

  def restore_snapshot
    @buffer, @cursor = @history.pop if @history.length > 0
  end
end

class Buffer
  def initialize(lines)
    @lines = lines
  end

  def render
    @lines.each do |line|
      $stdout.write(line + "\r\n") # \r needed because in IO.console.raw mode \n just goes down one line, but in the same column
    end
  end 

  def insert(char, row, col)
    lines = @lines.map(&:dup)
    lines.fetch(row).insert(col, char)
    Buffer.new(lines)
  end

  def delete(row, col)
    lines = @lines.map(&:dup)
    lines.fetch(row).slice!(col)
    Buffer.new(lines)
  end
  
  def split_line(row, col)
    lines = @lines.map(&:dup)
    line = lines.fetch(row)
    line1 = line[0...col]
    line2 = line[col..-1]
    lines[row..row] = [line1, line2] 
    Buffer.new(lines)
  end

  def line_count
    @lines.count
  end

  def line_length(row)
    @lines.fetch(row).length
  end
end

class Cursor
  attr_reader :row, :col

  def initialize(row=0, col=0)
    @row = row
    @col = col
  end

  def up(buffer)
    Cursor.new(@row - 1, @col).clamp(buffer)
  end
  
  def down(buffer)
    Cursor.new(@row + 1, @col).clamp(buffer)
  end

  def left(buffer)
    Cursor.new(@row, @col - 1).clamp(buffer)
  end

  def right(buffer)
    Cursor.new(@row, @col + 1).clamp(buffer)
  end

  def clamp(buffer)
    row = @row.clamp(0, buffer.line_count - 1)
    col = @col.clamp(0, buffer.line_length(row))
    Cursor.new(row, col)
  end
end

class ANSI
  def self.clear_screen
    $stdout.write("\e[2J") # console command to clear screen
  end

  def self.move_cursor(row,col)
    $stdout.write("\e[#{row + 1};#{col + 1}H") # console command set cursor placement
  end
end

Editor.new.run
