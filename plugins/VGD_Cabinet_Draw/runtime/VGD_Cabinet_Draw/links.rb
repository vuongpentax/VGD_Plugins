module VGD_Cabinet_Draw
  # Liên kết giữa các cấu kiện của một tủ. Đây là nơi duy nhất định nghĩa "cấu kiện này bắt vào cấu kiện nào",
  # để co giãn, kiểm tra và các tính năng sau này cùng hiểu một quy tắc.
  #   - Cánh: có một bản lề, bắt vào tấm vỏ tủ theo hướng mở (trái→hông trái, phải→hông phải,
  #     mở lên→nóc, mở xuống→đáy). Hướng mở 'none' thì không có bản lề, không có liên kết.
  #   - Tay nắm: gắn vào cánh/mặt hộc, cách mép đã chọn một khoảng mm (xem Operations.add_handle).
  #   - Mặt và thùng ngăn kéo, khoang, xà chặn, hộc tủ áo: cùng một bước tạo (op) thì là một nhóm.
  module Links
    extend self

    # Hướng mở → vai trò tấm vỏ tủ chứa bản lề.
    HINGE_PART = { 'left' => 'side_left', 'right' => 'side_right', 'top' => 'top', 'bottom' => 'bottom' }.freeze
    HINGE_LABEL = { 'left' => 'hông trái', 'right' => 'hông phải', 'top' => 'nóc', 'bottom' => 'đáy' }.freeze
    # Thứ tự xử lý: cánh mở lên/xuống trước, rồi cánh mở ngang (ưu tiên theo yêu cầu).
    PRIORITY = { 'top' => 0, 'bottom' => 0, 'left' => 1, 'right' => 1 }.freeze
    # Bản lề cốc 35 mm cộng khe: mép cánh phải nằm trong khoảng này quanh mặt của tấm bắt bản lề.
    HINGE_REACH = 40.0.mm

    def hinge_role(door)
      HINGE_PART[Operations.opening_type_of(door)]
    end

    # Cánh theo thứ tự xử lý (ổn định: giữ thứ tự cũ trong cùng một mức ưu tiên).
    def ordered(doors)
      doors.each_with_index.sort_by { |door, index| [PRIORITY.fetch(Operations.opening_type_of(door), 2), index] }.map(&:first)
    end

    # Danh sách lỗi liên kết (chuỗi tiếng Việt), rỗng nếu mọi bản lề còn bắt được vào tấm vỏ tủ.
    def problems(shell, doors)
      carcass = Interior.carcass(shell)
      ordered(doors).each_with_object([]) do |door, out|
        role = hinge_role(door)
        next unless role
        label = HINGE_LABEL.fetch(Operations.opening_type_of(door))
        part = carcass[role] || (role == 'top' ? carcass['rail_front'] : nil) || (role == 'bottom' ? carcass['rail_front_bottom'] : nil)
        name = "Cánh #{door.get_attribute(Schema::DICTIONARY, 'region_id')}"
        unless part
          out << "#{name} mở về phía #{label} nhưng không có #{label} để bắt bản lề."
          next
        end
        gap = edge_gap(door, part, role)
        out << "#{name} không còn sát #{label} để bắt bản lề (lệch #{gap.to_mm.round(1)} mm)." if gap > HINGE_REACH
      end
    end

    # Ném lỗi nếu có bản lề không còn bắt được (dùng trước khi sửa model).
    def check!(shell, doors)
      list = problems(shell, doors)
      raise list.join(' ') unless list.empty?
    end

    # Khoảng cách (inch) từ mép cánh đặt bản lề tới mặt gần nhất của tấm vỏ tủ chứa bản lề.
    def edge_gap(door, part, role)
      door_box = Operations.door_bounds(door)
      case role
      when 'side_left' then [(door_box[0] - part[0]).abs, (door_box[0] - part[3]).abs].min
      when 'side_right' then [(door_box[3] - part[0]).abs, (door_box[3] - part[3]).abs].min
      when 'top' then [(door_box[5] - part[2]).abs, (door_box[5] - part[5]).abs].min
      else [(door_box[2] - part[2]).abs, (door_box[2] - part[5]).abs].min
      end
    end
  end
end
