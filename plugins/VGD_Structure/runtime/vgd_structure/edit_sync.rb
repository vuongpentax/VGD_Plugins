module VGD
  module Structure
    # Phát hiện phần tử đã dựng bị sửa TRONG SketchUp (P7b): chụp vị trí (X, Y mm, góc quanh trục đứng, độ) của từng phần tử do plugin dựng, so lại
    # sau khi người dùng sửa. Chỉ nhận dời ngang, xoay quanh trục đứng và xóa; đổi cao độ hoặc co giãn bị bỏ qua (dựng lại sẽ đưa về đúng dữ liệu).
    # Nhóm (cả nhóm "Cột - Tầng 1") bị dời cả khối hoặc xóa thì không coi là sửa từng phần tử. Chưa xác minh trong SketchUp thật.
    module EditSync
      Entry = Struct.new(:entity, :group, :kind, :level, :ref, :pose, :group_pose)

      # {[loại, tầng, mã] => Entry}
      def self.snapshot(model)
        out = {}
        model.entities.grep(Sketchup::Group).each do |g|
          next unless g.valid?
          next unless ModelSync::PLAN_KINDS.key?(g.get_attribute(Schema::DICTIONARY, 'kind'))
          g.entities.to_a.each do |e|
            next unless e.respond_to?(:get_attribute) && !e.is_a?(Sketchup::Group)
            next unless e.get_attribute('VGD_BIM_SOURCE', 'plugin') == Schema::PLUGIN_ID
            ui = ModelSync::UI_KIND[e.get_attribute('VGD_BIM_SOURCE', 'kind').to_s] or next
            level, ref = e.get_attribute('VGD_BIM_SOURCE', 'ref').to_s.split(':', 2)
            next unless level && ref
            out[[ui, level, ref]] = Entry.new(e, g, ui, level, ref, pose(g, e), group_pose(g))
          end
        end
        out
      end

      # Vị trí gốc của thể hiện trong thế giới: [x mm, y mm, góc độ].
      def self.pose(group, instance)
        t = group.transformation * instance.transformation
        o = t.origin
        x = t.xaxis
        [o.x.to_mm, o.y.to_mm, Math.atan2(x.y, x.x) * 180.0 / Math::PI]
      end

      def self.group_pose(group)
        t = group.transformation
        [t.origin.x.to_mm, t.origin.y.to_mm, t.origin.z.to_mm, Math.atan2(t.xaxis.y, t.xaxis.x) * 180.0 / Math::PI]
      end

      def self.angle_delta(from, to)
        d = (to - from) % 360.0
        d > 180.0 ? d - 360.0 : d
      end

      # Danh sách thay đổi (định dạng của ModelEdit) giữa ảnh chụp và model hiện tại.
      def self.changes(snapshot)
        out = []
        snapshot.values.group_by(&:group).each do |group, entries|
          next unless group.valid?
          next if entries.any? { |en| group_pose(group).zip(en.group_pose).any? { |a, b| (a - b).abs > 0.01 } } # cả nhóm bị dời / xoay: không phải sửa từng phần tử
          found = entries.map { |en| [en, en.entity.valid?] }
          found.each { |en, ok| out << {'kind' => en.kind, 'level' => en.level, 'ref' => en.ref, 'erase' => true} unless ok }
          found.each { |en, ok| (c = pose_change(en)) && out << c if ok }
        end
        out
      end

      def self.pose_change(entry)
        now = pose(entry.group, entry.entity)
        old = entry.pose
        change = {'kind' => entry.kind, 'level' => entry.level, 'ref' => entry.ref,
                  'from' => [old[0].round(1), old[1].round(1)], 'to' => [now[0].round(1), now[1].round(1)], 'dangle' => angle_delta(old[2], now[2]).round(2)}
        ModelEdit.moved?(change) ? change : nil
      end

      # Bản vá cho từng thay đổi: {patches: [...], skipped: [lý do]}.
      def self.patches(state, changes)
        patches = []
        skipped = []
        changes.each do |c|
          r = c['erase'] ? ModelEdit.erase(state, c) : ModelEdit.move(state, c)
          r[:skip] ? skipped << r[:skip] : patches << r
        end
        {patches: patches, skipped: skipped}
      end
    end
  end
end
