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
