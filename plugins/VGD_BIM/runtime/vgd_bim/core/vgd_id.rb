require 'securerandom'

module VGD
  module BIM
    # VGD ID: mã định danh ổn định của một đối tượng (UUID 128 bit ngẫu nhiên, chữ thường), gắn với món suốt đời, người dùng không phải đọc hay sửa.
    # Khác với Mã đối tượng (`code`, do người dùng đặt, đổi được). Lưu ở dictionary RIÊNG `VGD_BIM_ID` (khóa `guid`), không ở `VGD_BIM`:
    # vì có dictionary `VGD_BIM` là món đã "có dữ liệu VGD" (Data.has_data?), ghi ID không được làm đổi nghĩa đó.
    # Giữ đủ 128 bit để sau này đổi chính xác sang IFC GlobalId (22 ký tự). Xem docs/vgd_bim/ROADMAP.md mục 3.
    # SketchUp copy cả dictionary khi copy món nên ID bị nhân đôi: duplicates / fix_plan phát hiện, giữ ID cho món cũ nhất (mã bền nhỏ nhất).
    module VgdId
      DICTIONARY = 'VGD_BIM_ID'.freeze
      KEY = 'guid'.freeze
      PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

      def self.generate
        SecureRandom.uuid
      end

      def self.valid?(value)
        value.is_a?(String) && value.match?(PATTERN)
      end

      # Dạng ngắn cho người đọc, ví dụ VGD-8A42F1. Dữ liệu gốc vẫn là UUID đủ 128 bit.
      def self.short(id)
        valid?(id) ? "VGD-#{id[0, 6].upcase}" : ''
      end

      # ID đã lưu trong món; không có hoặc hỏng thì rỗng.
      def self.read(entity)
        return '' unless entity.respond_to?(:get_attribute)
        value = entity.get_attribute(DICTIONARY, KEY)
        valid?(value) ? value : ''
      end

      # Gán ID cho món chưa có (giữ nguyên nếu đã có hợp lệ). Gọi trong một thao tác của người gọi (Data.transaction).
      def self.assign(entity)
        existing = read(entity)
        return existing unless existing.empty?
        write(entity, generate)
      end

      # Cấp ID mới thay ID hiện có (dùng khi trùng).
      def self.renew(entity)
        write(entity, generate)
      end

      def self.write(entity, id)
        raise ArgumentError, 'Đối tượng không hỗ trợ VGD ID hoặc không còn tồn tại.' unless entity.respond_to?(:set_attribute) && entity.respond_to?(:locked?) && (!entity.respond_to?(:valid?) || entity.valid?)
        raise ArgumentError, 'Đối tượng đang bị khóa.' if entity.locked?
        entity.set_attribute(DICTIONARY, KEY, id)
        id
      end

      # items: [{index:, guid:, locked:}]. Trả về chỉ số dòng cần gán, giữ nguyên, và bị khóa (không gán được).
      def self.assign_plan(items)
        plan = {assign: [], keep: [], locked: []}
        items.each do |item|
          if valid?(item[:guid]) then plan[:keep] << item[:index]
          elsif item[:locked] then plan[:locked] << item[:index]
          else plan[:assign] << item[:index]
          end
        end
        plan
      end

      # items: [{index:, pid:, guid:}]. Các nhóm dòng dùng chung một ID hợp lệ (mỗi nhóm có từ 2 dòng).
      def self.duplicates(items)
        items.select { |item| valid?(item[:guid]) }.group_by { |item| item[:guid] }.values.select { |group| group.size > 1 }.map { |group| group.map { |item| item[:index] } }
      end

      # Mỗi nhóm trùng: giữ ID cho món có mã bền nhỏ nhất (món không có mã bền xếp sau cùng), các món còn lại cấp ID mới; món bị khóa không đổi được.
      def self.fix_plan(items)
        plan = {keep: [], renew: [], locked: []}
        items.select { |item| valid?(item[:guid]) }.group_by { |item| item[:guid] }.each_value do |group|
          next if group.size < 2
          ordered = group.sort_by { |item| [item[:pid] || Float::INFINITY, item[:index]] }
          plan[:keep] << ordered.first[:index]
          ordered.drop(1).each { |item| (item[:locked] ? plan[:locked] : plan[:renew]) << item[:index] }
        end
        plan.transform_values(&:sort)
      end
    end
  end
end
