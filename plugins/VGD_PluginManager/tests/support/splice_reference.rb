# encoding: UTF-8
# Bản tham chiếu bằng Ruby của hàm Set-ShortcutLines trong src/VGD_PluginManager/helper/apply_layout.ps1.
# Dùng để kiểm chứng thuật toán chỉnh theo dòng ngoài Windows; bản PowerShell phải làm đúng như vậy.
module Splice
  SHORTCUT_KEY = /\A(Num_Shortcuts|Shortcut_\d+)\z/
  ENTRY = /\A(\s+)("(?:[^"\\]|\\.)*")\s*:\s*(.*?)(,?)\s*\z/

  def self.json_string(str)
    out = +'"'
    str.each_char do |ch|
      code = ch.ord
      out << if code == 34 then '\\"'
             elsif code == 92 then '\\\\'
             elsif code < 32 then format('\\u%04x', code)
             else ch
             end
    end
    out << '"'
  end

  # text: nội dung SharedPreferences.json; shortcuts: { 'Num_Shortcuts' => n, 'Shortcut_1' => '...' }
  def self.apply(text, shortcuts)
    eol = text.include?("\r\n") ? "\r\n" : "\n"
    lines = text.split(/\r?\n/, -1)

    win_idx = lines.index { |l| l =~ /\A(\s*)"Windows Only"\s*:\s*\{\s*\z/ } or raise 'Khong thay "Windows Only"'
    win_indent = lines[win_idx][/\A\s*/].size

    set_idx = nil
    ((win_idx + 1)...lines.size).each do |i|
      l = lines[i]
      if l =~ /\A(\s*)"Settings"\s*:\s*\{\s*\z/
        set_idx = i
        break
      end
      break if l =~ /\A(\s*)\S/ && $1.size <= win_indent
    end
    raise 'Khong thay "Settings"' unless set_idx
    set_indent = lines[set_idx][/\A\s*/].size

    end_idx = ((set_idx + 1)...lines.size).find { |i| lines[i] =~ /\A(\s*)\}\s*,?\s*\z/ && $1.size == set_indent }
    raise 'Khong thay cuoi Settings' unless end_idx

    keep = []
    insert_at = nil
    indent = nil
    ((set_idx + 1)...end_idx).each do |i|
      l = lines[i]
      next if l.strip.empty?
      m = ENTRY.match(l) or raise "Khong hieu dong: #{l}"
      raise 'Settings co muc long nhau' if m[3] =~ /\A[\{\[]/
      indent ||= m[1]
      name = m[2][1..-2]
      if name =~ SHORTCUT_KEY
        insert_at ||= keep.size
        next
      end
      orig = l.rstrip
      orig = orig[0..-2] if orig.end_with?(',')
      keep << orig
    end
    indent ||= ' ' * (set_indent + 4)
    insert_at ||= keep.size

    names = shortcuts.keys.select { |k| k =~ SHORTCUT_KEY }.sort
    count = names.count { |k| k != 'Num_Shortcuts' }
    new_lines = names.map do |k|
      v = shortcuts[k]
      val = if k == 'Num_Shortcuts' then count.to_s
            elsif v.is_a?(String) then json_string(v)
            else v.to_i.to_s
            end
      "#{indent}#{json_string(k)}: #{val}"
    end
    keep.insert(insert_at, *new_lines)
    out_lines = keep.each_with_index.map { |l, i| i < keep.size - 1 ? "#{l}," : l }
    lines[(set_idx + 1)...end_idx] = out_lines
    lines.join(eol)
  end
end

# Bản tham chiếu Ruby của Get-PrivateLayout / Set-PrivateLayout trong helper/apply_layout.ps1:
# chụp và áp các mục layout trong PrivatePreferences.json bằng cách chỉnh theo dòng (giữ nguyên mọi byte khác).
# Khóa là văn bản thô giữa hai dấu nháy trong file (ví dụ RubyWorkspace\\RubyToolBar-59648, hai dấu gạch chéo).
module PrivateSplice
  LAYOUT = /\A(?:(?:Qt)?RubyWorkspace\\\\|Workspace\\\\)|\AToolbarSettings\z/
  MAIN_WINDOW_KEYS = %w[DockWidgetState ToolBarState].freeze
  SCALAR = '(?:true|false|null|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|"(?:[^"\\\\]|\\\\.)*")'

  Entry = Struct.new(:key, :block, :lines)

  def self.layout_key?(key)
    key =~ LAYOUT ? true : false
  end

  def self.find_computer_block(lines)
    start = lines.index { |l| l =~ /\A(\s*)"This Computer Only"\s*:\s*\{\s*\z/ } or raise 'Khong thay "This Computer Only"'
    indent = lines[start][/\A\s*/].size
    last = ((start + 1)...lines.size).find { |i| lines[i] =~ /\A#{' ' * indent}\},?\s*\z/ } or raise 'Khong thay cuoi "This Computer Only"'
    [start, last, indent]
  end

  # Tách các mục ở thụt lề entry_indent trong khoảng dòng from..to. Dòng cuối mỗi mục đã bỏ dấu phẩy.
  def self.split_entries(lines, from, to, entry_indent)
    sp = ' ' * entry_indent
    key_pat = /\A#{sp}("(?:[^"\\]|\\.)*")\s*:\s*(.*?)(,?)\s*\z/
    close_pat = /\A#{sp}[\}\]],?\s*\z/
    entries = []
    i = from
    while i <= to
      l = lines[i]
      (i += 1) && next if l.strip.empty?
      m = key_pat.match(l) or raise "Khong hieu dong (thut le #{entry_indent}): L#{i + 1}"
      key = m[1][1..-2]
      last = i
      block = false
      if m[2] == '{' || m[2] == '['
        block = true
        last = ((i + 1)..to).find { |j| lines[j] =~ close_pat } or raise "Muc #{key} khong co dong dong"
      end
      ent = lines[i..last].dup
      ent[-1] = ent[-1].rstrip.sub(/,\z/, '')
      entries << Entry.new(key, block, ent)
      i = last + 1
    end
    entries
  end

  # Khối phẳng (chỉ thuộc tính vô hướng ở thụt lề +4); trả về các dòng đã bỏ dấu phẩy, hoặc nil
  def self.flat_block(lines, indent)
    in1 = ' ' * (indent + 4)
    in2 = ' ' * (indent + 8)
    return nil if lines.size < 2
    return nil unless lines[0] =~ /\A#{in1}"(?:[^"\\]|\\.)*"\s*:\s*\{\z/
    return nil unless lines[-1] == "#{in1}}"
    inner = lines[1..-2].map { |l| l.sub(/,\z/, '') }
    return nil unless inner.all? { |l| l =~ /\A#{in2}"(?:[^"\\]|\\.)*"\s*:\s*#{SCALAR}\z/ }
    [lines[0], *inner, lines[-1]]
  end

  # Trả về { blocks: { khóa => [dòng] }, main_window: { khóa => '"khóa": "giá trị"' }, skipped: n }
  def self.capture(text)
    lines = text.split(/\r?\n/, -1)
    start, last, indent = find_computer_block(lines)
    blocks = {}
    mw = {}
    skipped = 0
    split_entries(lines, start + 1, last - 1, indent + 4).each do |e|
      next unless e.block
      if layout_key?(e.key)
        fb = flat_block(e.lines, indent)
        fb ? blocks[e.key] = fb : skipped += 1
      elsif e.key == 'MainWindow'
        split_entries(e.lines, 1, e.lines.size - 2, indent + 8).each do |ie|
          mw[ie.key] = ie.lines[0].strip if !ie.block && MAIN_WINDOW_KEYS.include?(ie.key)
        end
      end
    end
    { blocks: blocks, main_window: mw, skipped: skipped }
  end

  def self.with_commas(entry_lines_list)
    out = []
    entry_lines_list.each_with_index do |lines, i|
      ls = lines.dup
      ls[-1] = "#{ls[-1]}," if i < entry_lines_list.size - 1
      out.concat(ls)
    end
    out
  end

  def self.format_block(block_lines)
    inner = block_lines[1..-2]
    inner = inner.each_with_index.map { |l, i| i < inner.size - 1 ? "#{l}," : l }
    [block_lines[0], *inner, block_lines[-1]]
  end

  def self.set_main_window(entry, mw, entry_indent)
    pad = ' ' * (entry_indent + 4)
    inner = split_entries(entry.lines, 1, entry.lines.size - 2, entry_indent + 4)
    done = {}
    items = inner.map do |ie|
      if !ie.block && mw.key?(ie.key)
        done[ie.key] = true
        ["#{pad}#{mw[ie.key]}"]
      else
        ie.lines
      end
    end
    mw.keys.sort.each { |k| items << ["#{pad}#{mw[k]}"] unless done[k] }
    lines = [entry.lines[0], *with_commas(items), entry.lines[-1]]
    Entry.new('MainWindow', true, lines)
  end

  def self.apply(text, blocks, main_window)
    eol = text.include?("\r\n") ? "\r\n" : "\n"
    lines = text.split(/\r?\n/, -1)
    start, last, indent = find_computer_block(lines)
    entry_indent = indent + 4
    keys = blocks.keys.select { |k| layout_key?(k) }.sort
    keys.each { |k| raise "Muc layout khong hop le: #{k}" unless (fb = flat_block(blocks[k], indent)) && fb[0] =~ /\A\s*"#{Regexp.escape(k)}"/ }
    new_entries = []
    insert_at = nil
    mw_done = false
    split_entries(lines, start + 1, last - 1, entry_indent).each do |e|
      if e.block && layout_key?(e.key)
        insert_at ||= new_entries.size
        next
      end
      if e.block && e.key == 'MainWindow' && !main_window.empty?
        new_entries << set_main_window(e, main_window, entry_indent)
        mw_done = true
        next
      end
      new_entries << e
    end
    insert_at ||= new_entries.size
    new_entries.insert(insert_at, *keys.map { |k| Entry.new(k, true, format_block(blocks[k])) })
    unless mw_done || main_window.empty?
      pad = ' ' * (entry_indent + 4)
      body = with_commas(main_window.keys.sort.map { |k| ["#{pad}#{main_window[k]}"] })
      new_entries << Entry.new('MainWindow', true, ["#{' ' * entry_indent}\"MainWindow\": {", *body, "#{' ' * entry_indent}}"])
    end
    lines[(start + 1)...last] = with_commas(new_entries.map(&:lines))
    lines.join(eol)
  end
end
