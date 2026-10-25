module VGD_Cabinet_Draw
  # Các tấm của thùng ngăn kéo theo loại ray và loại đáy. Ruby thuần (không gọi SketchUp), đơn vị SketchUp.
  # Mỗi tấm: [tên, vai trò, x0, x1, y0, y1, z0, z1]; hệ trục thùng tủ (X trái→phải, Y trước→sau, Z lên).
  #   đặt dưới (under): đáy phủ dưới các thành (hông ray bi đặt lên đáy).
  #   lọt giữa 4 thành (inset): đáy nằm giữa hai hông, mặt trước, mặt sau; mép dưới ngang mép dưới các thành.
  #   ngậm rãnh (groove): đáy mỏng chồng vào 4 thành một đoạn "ngậm rãnh"; rãnh chỉ là dấu nên ván giữ nguyên là khối sạch.
  module DrawerParts
    extend self

    BOTTOM_TYPES = %w[under inset groove].freeze
    BOTTOM_LABELS = { 'under' => 'đặt dưới', 'inset' => 'lọt giữa 4 thành', 'groove' => 'ngậm rãnh' }.freeze
    MIN_WALL_LEFT = 3.0 / 25.4 # phần thành còn lại tối thiểu sau rãnh (3 mm)
    MIN_ABOVE_BOTTOM = 10.0 / 25.4

    def bottom_type(value)
      BOTTOM_TYPES.include?(value.to_s) ? value.to_s : 'under'
    end

    # box: { slide: 'side'|'under', bottom: loại đáy, x0, x1, y0, y1, z0, top, side: dày thành, bottom_t: dày đáy,
    #        lift: nâng đáy ray âm, groove_depth: độ ngậm rãnh, groove_height: cao rãnh tính từ mép dưới mặt trước/sau }
    def parts(box)
      type = bottom_type(box[:bottom])
      under_mount = box[:slide] == 'under'
      x0, x1, y0, y1, z0, top = box.values_at(:x0, :x1, :y0, :y1, :z0, :top)
      st, bt = box[:side], box[:bottom_t]
      base = under_mount ? z0 + box[:lift].to_f : z0 # mép dưới mặt trước/sau (và đáy lọt)
      case type
      when 'inset' then inset_parts(x0, x1, y0, y1, z0, base, top, st, bt)
      when 'groove' then groove_parts(box, x0, x1, y0, y1, z0, base, top, st, bt)
      else under_parts(under_mount, x0, x1, y0, y1, z0, base, top, st, bt)
      end
    end

    def under_parts(under_mount, x0, x1, y0, y1, z0, base, top, st, bt)
      if under_mount
        [['Hông Trái', 'drawer_side', x0, x0 + st, y0, y1, z0, top],
         ['Hông Phải', 'drawer_side', x1 - st, x1, y0, y1, z0, top],
         ['Đáy', 'drawer_bottom', x0 + st, x1 - st, y0, y1, base, base + bt],
         ['Mặt Trước', 'drawer_box_front', x0 + st, x1 - st, y0, y0 + st, base + bt, top],
         ['Mặt Sau', 'drawer_box_back', x0 + st, x1 - st, y1 - st, y1, base + bt, top]]
      else
        [['Đáy', 'drawer_bottom', x0, x1, y0, y1, z0, z0 + bt],
         ['Hông Trái', 'drawer_side', x0, x0 + st, y0, y1, z0 + bt, top],
         ['Hông Phải', 'drawer_side', x1 - st, x1, y0, y1, z0 + bt, top],
         ['Mặt Trước', 'drawer_box_front', x0 + st, x1 - st, y0, y0 + st, z0 + bt, top],
         ['Mặt Sau', 'drawer_box_back', x0 + st, x1 - st, y1 - st, y1, z0 + bt, top]]
      end
    end

    def inset_parts(x0, x1, y0, y1, z0, base, top, st, bt)
      [['Hông Trái', 'drawer_side', x0, x0 + st, y0, y1, z0, top],
       ['Hông Phải', 'drawer_side', x1 - st, x1, y0, y1, z0, top],
       ['Mặt Trước', 'drawer_box_front', x0 + st, x1 - st, y0, y0 + st, base, top],
       ['Mặt Sau', 'drawer_box_back', x0 + st, x1 - st, y1 - st, y1, base, top],
       ['Đáy', 'drawer_bottom', x0 + st, x1 - st, y0 + st, y1 - st, base, base + bt]]
    end

    def groove_parts(box, x0, x1, y0, y1, z0, base, top, st, bt)
      g = box[:groove_depth].to_f
      zg = base + box[:groove_height].to_f
      raise ArgumentError, 'Độ ngậm rãnh phải nhỏ hơn dày thành ít nhất 3 mm.' if g > st - MIN_WALL_LEFT
      raise ArgumentError, 'Rãnh đáy nằm quá cao so với thành thùng: giảm "Cao rãnh" hoặc tăng chiều cao hộc.' if zg + bt > top - MIN_ABOVE_BOTTOM
      [['Hông Trái', 'drawer_side', x0, x0 + st, y0, y1, z0, top],
       ['Hông Phải', 'drawer_side', x1 - st, x1, y0, y1, z0, top],
       ['Mặt Trước', 'drawer_box_front', x0 + st, x1 - st, y0, y0 + st, base, top],
       ['Mặt Sau', 'drawer_box_back', x0 + st, x1 - st, y1 - st, y1, base, top],
       ['Đáy', 'drawer_bottom', x0 + st - g, x1 - st + g, y0 + st - g, y1 - st + g, zg, zg + bt]]
    end
  end
end
