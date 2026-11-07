require 'json'

module VGD
  module BIM
    module UI
      # Phần của cửa sổ BIM lo cho Mặt trước: tự phát hiện, đặt tay (theo hướng nhìn, xoay 90°, đảo chiều) và xóa. Chỉ ghi dictionary của
      # định nghĩa (xem Front), không đổi hình học. Mỗi lệnh là một bước hoàn tác. Trộn vào UI::Dialog (dùng @model, @table_records...).
      module FrontActions
        MAX_FRONT_BATCH = 500 # số đối tượng tối đa cho một lần phát hiện
        SET_MODES = %w[dir camera turn opposite].freeze

        def register_front_callbacks
          @dialog.add_action_callback('front_detect') { |_ctx, payload| safely { front_detect(JSON.parse(payload)) } }
          @dialog.add_action_callback('front_set') { |_ctx, payload| safely { front_set(JSON.parse(payload)) } }
          @dialog.add_action_callback('front_clear') { |_ctx, payload| safely { front_clear(JSON.parse(payload)) } }
          @dialog.add_action_callback('front_align_preview') { |_ctx, payload| safely { front_align_preview(JSON.parse(payload)) } }
          @dialog.add_action_callback('front_align') { |_ctx, payload| safely { front_align(JSON.parse(payload)) } }
        end

        # payload: {'indexes' => [...], 'overwrite' => true / false}. Món đã đặt tay được giữ nguyên trừ khi overwrite.
        def front_detect(payload)
          check_model!
          records = front_records(payload)
          raise "Mỗi lần phát hiện tối đa #{MAX_FRONT_BATCH} đối tượng. Hãy chọn ít hơn." if records.size > MAX_FRONT_BATCH
          overwrite = payload['overwrite'] == true
          skipped = {locked: 0, manual: 0}
          groups = {} # định nghĩa => [[record, kết quả đo], ...]
          records.each do |record|
            definition = Geometry.definition(record[:entity])
            if record[:locked] || record[:entity].locked?
              skipped[:locked] += 1
            elsif !overwrite && Front.read(definition)[:source] == 'manual'
              skipped[:manual] += 1
            else
              result = FrontProbe.measure(@model, record)
              (groups[definition] ||= []) << [record, result] if result
            end
          end
          verdicts = groups.transform_values { |list| front_verdict(list.map(&:last)) }
          Data.transaction(@model, 'VGD_BIM · Phát hiện mặt trước') do
            verdicts.each { |definition, v| Front.write(definition, v[:dir], source: 'auto', confidence: v[:confidence], note: v[:notes].join('; ')) if v[:dir] }
          end
          table_build
          show_outline
          emit('message', {text: front_detect_text(verdicts, skipped, records.size)})
        end

        # Một component có nhiều bản sao: các kết quả phải trùng hướng cục bộ. Trùng thì lấy độ tin cậy cao nhất, mâu thuẫn thì lấy
        # hướng nhiều phiếu nhất nhưng chỉ tin cậy thấp (cần duyệt tay).
        def front_verdict(results)
          votes = results.map { |r| r[:dir] }.compact
          return {dir: nil, confidence: 'low', notes: results.flat_map { |r| r[:notes] }.uniq} if votes.empty?
          counts = votes.tally
          dir = counts.max_by { |_, n| n }.first
          agreeing = results.select { |r| r[:dir] == dir }
          return {dir: dir, confidence: 'low', notes: ['các bản sao cho kết quả khác nhau: cần duyệt'] + agreeing.flat_map { |r| r[:notes] }.uniq} if counts.size > 1
          best = agreeing.map { |r| Front::CONFIDENCES.index(r[:confidence]) }.min
          {dir: dir, confidence: Front::CONFIDENCES[best], notes: agreeing.flat_map { |r| r[:notes] }.uniq}
        end

        def front_detect_text(verdicts, skipped, total)
          found = verdicts.values.select { |v| v[:dir] }
          by = Front::CONFIDENCES.to_h { |c| [c, found.count { |v| v[:confidence] == c }] }
          text = "Đã xác định mặt trước cho #{found.size} loại: tin cậy cao #{by['high']}, trung bình #{by['medium']}, cần duyệt #{by['low']}."
          unresolved = verdicts.size - found.size
          text += " Chưa xác định được #{unresolved} loại (cần đặt tay)." if unresolved.positive?
          text += " Bỏ qua #{skipped[:manual]} đối tượng đã đặt tay." if skipped[:manual].positive?
          text += " Bỏ qua #{skipped[:locked]} đối tượng bị khóa." if skipped[:locked].positive?
          text += " (#{total} đối tượng được xem xét)" if total > verdicts.size
          text
        end

        # payload: {'indexes' => [...], 'mode' => 'dir' | 'camera' | 'turn' | 'opposite', 'dir' => '+x' (chỉ khi mode = dir)}
        def front_set(payload)
          check_model!
          mode = payload['mode']
          raise 'Cách đặt mặt trước không hợp lệ.' unless SET_MODES.include?(mode)
          dir = payload['dir']
          raise 'Hướng mặt trước không hợp lệ.' if mode == 'dir' && !Front.valid?(dir)
          records = front_records(payload)
          editable = records.reject { |record| record[:locked] || record[:entity].locked? }
          raise 'Đối tượng đang bị khóa nên không đặt được mặt trước.' if editable.empty?
          plan = {} # định nghĩa => hướng mới
          missing = 0
          editable.each do |record|
            definition = Geometry.definition(record[:entity])
            wanted = front_wanted(mode, dir, record, definition)
            if wanted.nil? then missing += 1; next end
            raise 'Các bản sao của cùng một component đang cho hướng khác nhau. Hãy chọn từng bản sao.' if plan.key?(definition) && plan[definition] != wanted
            plan[definition] = wanted
          end
          if plan.empty?
            raise 'Không xác định được hướng nhìn ngang của camera. Hãy xoay camera nhìn vào mặt trước của món (không nhìn thẳng từ trên xuống).' if mode == 'camera'
            raise 'Chưa có mặt trước để xoay / đảo. Hãy phát hiện hoặc đặt tay trước.'
          end
          Data.transaction(@model, 'VGD_BIM · Đặt mặt trước') { plan.each { |definition, wanted| Front.write(definition, wanted) } }
          table_build
          show_outline
          text = "Đã đặt mặt trước cho #{plan.size} loại (thủ công)."
          text += " Bỏ qua #{missing} đối tượng chưa có mặt trước." if missing.positive?
          text += " Bỏ qua #{records.size - editable.size} đối tượng bị khóa." if records.size > editable.size
          emit('message', {text: text})
        end

        def front_wanted(mode, dir, record, definition)
          case mode
          when 'dir' then dir
          when 'camera' then FrontProbe.camera_direction(@model.active_view, record)
          else
            current = Front.read(definition)[:dir]
            current && (mode == 'turn' ? Front.turn(current) : Front.opposite(current))
          end
        end

        def front_clear(payload)
          check_model!
          records = front_records(payload)
          editable = records.reject { |record| record[:locked] || record[:entity].locked? }
          raise 'Đối tượng đang bị khóa nên không xóa được mặt trước.' if editable.empty?
          definitions = editable.map { |record| Geometry.definition(record[:entity]) }.uniq
          Data.transaction(@model, 'VGD_BIM · Xóa mặt trước') { definitions.each { |definition| Front.clear(definition) } }
          table_build
          show_outline
          emit('message', {text: "Đã xóa mặt trước của #{definitions.size} loại."})
        end

        # ---- Sửa trục theo mặt trước (ĐỔI HÌNH HỌC: xem FrontAlign) ----
        # Xem trước chỉ tính kế hoạch rồi gửi tóm tắt về giao diện; không đổi gì trong model.
        def front_align_preview(payload)
          check_model!
          plan = FrontAlign.plan(front_align_records(payload))
          emit('front_align_plan', front_align_summary(payload, plan))
        end

        # payload: {'indexes' => [...]}. Tính lại kế hoạch ngay lúc áp dụng (không tin bản xem trước cũ), một thao tác duy nhất:
        # lỗi giữa chừng thì hủy cả thao tác nên model không bị sửa nửa chừng.
        def front_align(payload)
          check_model!
          plan = FrontAlign.plan(front_align_records(payload))
          raise 'Không có món nào cần sửa trục. Bấm Xem trước để biết lý do.' if plan[:items].empty?
          count = Data.transaction(@model, 'VGD_BIM · Sửa trục theo mặt trước') { FrontAlign.apply(plan) }
          table_build
          show_outline
          emit('front_align_plan', {cleared: true}) # xóa bản xem trước cũ ở giao diện
          instances = plan[:items].sum { |item| item[:instances].size }
          text = "Đã sửa trục cho #{count} loại (#{instances} bản sao): mặt trước giờ là -Y, hình trong model không đổi chỗ."
          text += " Bỏ qua #{plan[:skipped].size} loại." if plan[:skipped].any?
          emit('message', {text: text})
        end

        def front_align_summary(payload, plan)
          reasons = plan[:skipped].map { |item| item[:reason] }.tally.map { |reason, count| {reason: reason, count: count} }
          {key: payload['indexes'].map(&:to_i).sort, fix: plan[:items].size, instances: plan[:items].sum { |item| item[:instances].size },
           aligned: plan[:aligned], skipped: plan[:skipped].size, reasons: reasons, names: plan[:items].first(5).map { |item| item[:name] }}
        end

        # Sửa trục luôn cần chọn rõ các dòng (không mặc định "tất cả"), tối đa như lúc phát hiện.
        def front_align_records(payload)
          raise 'Hãy chọn các món cần sửa trục trong bảng.' unless payload['indexes'].is_a?(Array) && !payload['indexes'].empty?
          records = front_records(payload)
          raise "Mỗi lần sửa trục tối đa #{MAX_FRONT_BATCH} đối tượng. Hãy chọn ít hơn." if records.size > MAX_FRONT_BATCH
          records
        end

        # Các dòng bảng theo chỉ số giao diện gửi lên; không nói indexes thì lấy mọi dòng đang có trong bảng.
        def front_records(payload)
          indexes = payload['indexes'].is_a?(Array) && !payload['indexes'].empty? ? table_indexes(payload) : (0...@table_records.size).to_a
          records = indexes.map { |index| @table_records.fetch(index) { raise 'Bảng đã cũ. Hãy làm mới bảng.' } }
          raise 'Chưa có đối tượng nào trong bảng.' if records.empty?
          raise 'Đối tượng không còn tồn tại. Hãy làm mới bảng.' unless records.all? { |record| record[:path].all?(&:valid?) }
          records
        end
      end
    end
  end
end
