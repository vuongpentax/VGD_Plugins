# encoding: UTF-8
# Logic thuần của sơ đồ: gom cấu kiện giống nhau, sắp theo thứ tự lắp, kiểm tra số thứ tự, xuất SVG.
# Không gọi API SketchUp nên test được bằng Ruby thường (dev/test_tree.rb).
module VGD
  module Diagram
    module Tree
      extend self

      MAX_ORDER = 9999
      MIN_WIDTH = 240
      ROW_HEIGHT = 30
      INDENT = 24
      PADDING = 16
      CHAR_WIDTH = 8
      LINE_COLOR = '#A47D5C'.freeze

      # raw: [{'id', 'name', 'order', 'children' => [raw]}], đọc từ model, chưa gom.
      # Trả về các nút đã gom, sắp theo thứ tự lắp (chưa đặt xếp cuối, rồi theo tên).
      def build(raw_nodes)
        raw_nodes.group_by { |node| signature(node) }
                 .values
                 .map { |members| node_for(members) }
                 .sort_by { |node| [node['order'] ? 0 : 1, node['order'] || 0, node['name']] }
      end

      # Hai cấu kiện giống nhau khi cùng tên và cùng cấu trúc con.
      def signature(node)
        [node['name'], node['children'].map { |child| signature(child) }]
      end

      def node_for(members)
        representative = members.first
        ids = members.map { |member| member['id'] }
        orders = members.map { |member| member['order'] }.uniq
        {
          'key' => ids.first,
          'name' => representative['name'],
          'count' => members.size,
          'ids' => ids,
          # Nil nghĩa là chưa đặt, hoặc các bản trong nhóm có thứ tự khác nhau ('mixed').
          'order' => orders.size == 1 ? orders.first : nil,
          'mixed' => orders.size > 1,
          'children' => build(representative['children'])
        }
      end

      def find(nodes, key)
        nodes.each do |node|
          return node if node['key'] == key
          found = find(node['children'], key)
          return found if found
        end
        nil
      end

      # Danh sách các nút cùng cấp với nút có key (dùng để kiểm tra trùng số thứ tự).
      def siblings_of(nodes, key)
        return nodes if nodes.any? { |node| node['key'] == key }
        nodes.each do |node|
          found = siblings_of(node['children'], key)
          return found if found
        end
        nil
      end

      # Chuyển giá trị người dùng nhập thành số thứ tự (Integer) hoặc nil khi để trống.
      def parse_order(value)
        text = value.to_s.strip
        return nil if text.empty?
        raise ArgumentError, 'Thứ tự phải là số nguyên.' unless text.match?(/\A\d+\z/)
        number = text.to_i
        raise ArgumentError, "Thứ tự phải từ 1 đến #{MAX_ORDER}." unless (1..MAX_ORDER).cover?(number)
        number
      end

      # Kiểm tra toàn bộ thay đổi trước khi ghi model. changes: {key => giá trị nhập}.
      # Trả về {key => số thứ tự đã chuẩn hóa}. Ném ArgumentError nếu có lỗi.
      def plan(nodes, changes)
        normalized = changes.to_h { |key, value| [key, parse_order(value)] }
        normalized.each_key do |key|
          siblings = siblings_of(nodes, key)
          raise ArgumentError, 'Không tìm thấy cấu kiện, hãy làm mới sơ đồ.' unless siblings
          check_unique(with_orders(siblings, normalized))
        end
        normalized
      end

      # Các nút cùng cấp sau khi áp thứ tự mới (không đổi nút gốc).
      def with_orders(siblings, orders)
        siblings.map do |node|
          node.merge('order' => orders.key?(node['key']) ? orders[node['key']] : node['order'])
        end
      end

      def check_unique(siblings)
        siblings.select { |node| node['order'] }.group_by { |node| node['order'] }.each do |order, same|
          next if same.size == 1
          names = same.map { |node| "'#{node['name']}'" }.join(', ')
          raise ArgumentError, "Thứ tự #{order} trùng giữa #{names}. Hãy chọn số khác."
        end
      end

      def label(node)
        text = node['order'] ? "#{node['order']}. #{node['name']}" : node['name']
        node['count'] > 1 ? "#{text} × #{node['count']}" : text
      end

      def svg(nodes)
        rows = []
        flatten(nodes, 0, rows)
        width = [MIN_WIDTH, *rows.map { |depth, node| row_right(depth, node) + PADDING }].max
        height = [rows.size, 1].max * ROW_HEIGHT + 2 * PADDING
        body = if rows.empty?
                 [%(<text x="#{PADDING}" y="#{PADDING + 18}" fill="#222222">Chưa có cấu kiện nào</text>)]
               else
                 rows.each_with_index.map { |(depth, node), index| svg_row(depth, node, index) }
               end
        <<~SVG
          <?xml version="1.0" encoding="UTF-8"?>
          <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}" font-family="Segoe UI, Arial, sans-serif" font-size="14">
          #{body.join("\n")}
          </svg>
        SVG
      end

      private

      def flatten(nodes, depth, rows)
        nodes.each do |node|
          rows << [depth, node]
          flatten(node['children'], depth + 1, rows)
        end
      end

      def row_left(depth)
        PADDING + depth * INDENT
      end

      def row_width(node)
        label(node).length * CHAR_WIDTH + 2 * PADDING
      end

      def row_right(depth, node)
        row_left(depth) + row_width(node)
      end

      def svg_row(depth, node, index)
        top = PADDING + index * ROW_HEIGHT
        middle = top + ROW_HEIGHT / 2
        left = row_left(depth)
        parts = []
        # Nét nối từ mép trên dòng xuống giữa dòng, rồi sang phải tới ô cấu kiện.
        if depth > 0
          elbow = left - INDENT / 2
          parts << %(<path d="M#{elbow} #{top} V#{middle} H#{left}" fill="none" stroke="#{LINE_COLOR}"/>)
        end
        parts << %(<rect x="#{left}" y="#{top + 4}" width="#{row_width(node)}" height="#{ROW_HEIGHT - 8}" rx="6" fill="#F7F7F5" stroke="#{LINE_COLOR}"/>)
        parts << %(<text x="#{left + PADDING}" y="#{middle + 5}" fill="#222222">#{escape(label(node))}</text>)
        parts.join("\n")
      end

      def escape(text)
        text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
      end
    end
  end
end
