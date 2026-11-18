module VGD
  module Structure
    # VGD ID của phần tử (dictionary VGD_BIM_ID, khóa guid; hợp đồng docs/vgd_bim/BRIDGE.md): dựng lại giữ ID cũ của đúng phần tử (cùng mã vị trí),
    # phần tử mới nhận ID từ VGD_BIM qua cầu nối (loại vgd_id, lệnh generate) nếu BIM đã cài; chưa có BIM thì để trống, BIM gán sau bằng nút "Gán VGD ID".
    # Plugin KHÔNG tự sinh ID kiểu riêng.
    module IdKeeper
      DICTIONARY = 'VGD_BIM_ID'.freeze
      KEY = 'guid'.freeze
      PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/

      # Phần tử bị đổi mã vị trí do sửa trong SketchUp (mã cũ => mã mới, cả hai dạng 'mã tầng:mã'): `harvest` khai ID dưới mã mới để dựng lại giữ ID.
      def self.renaming(map)
        @renames = map.is_a?(Hash) ? map : {}
        yield
      ensure
        @renames = {}
      end

      # {mã vị trí (VGD_BIM_SOURCE.ref) => VGD ID} của các phần tử trong nhóm sắp bị thay.
      def self.harvest(group)
        return {} unless group
        group.entities.to_a.each_with_object({}) do |entity, out|
          next unless entity.respond_to?(:get_attribute)
          ref = entity.get_attribute('VGD_BIM_SOURCE', 'ref')
          id = entity.get_attribute(DICTIONARY, KEY)
          ref = (@renames || {}).fetch(ref, ref)
          out[ref] = id if ref.is_a?(String) && id.is_a?(String) && id.match?(PATTERN)
        end
      end

      # Gán ID cho phần tử mới dựng: ID cũ nếu có, không thì xin BIM; không có BIM thì bỏ qua. Mỗi ID chỉ dùng một lần (không nhân đôi).
      def self.assign(instance, ref, kept)
        id = kept.delete(ref) || generate
        instance.set_attribute(DICTIONARY, KEY, id) if id
        id
      end

      def self.generate
        return nil unless defined?(::VGD::Bridge) && ::VGD::Bridge.provider_for('vgd_id')
        id = ::VGD::Bridge.call('vgd_id', 'generate')
        id.is_a?(String) && id.match?(PATTERN) ? id : nil
      rescue StandardError
        nil
      end
    end
  end
end
