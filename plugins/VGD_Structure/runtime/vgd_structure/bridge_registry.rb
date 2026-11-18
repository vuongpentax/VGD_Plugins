# Danh bạ cầu nối VGD (bridge_version 1). Bản sao GIỐNG HỆT nằm ở mọi plugin dùng cầu nối (VGD_BIM, VGD_Room...) để không phụ thuộc thứ tự nạp:
# plugin nào nạp trước cũng định nghĩa được danh bạ, plugin nạp sau dùng lại. Đặc tả: docs/vgd_bim/BRIDGE.md.
module VGD
  module Bridge
    VERSION = 1 unless const_defined?(:VERSION)

    class << self
      def providers
        @providers ||= {}
      end

      # info: {bridge_version: 1, version: 'x.y.z', provides: ['room_volume'], commands: {'build' => callable, ...}}
      def register(id, info)
        raise ArgumentError, 'Mã plugin cầu nối không hợp lệ.' unless id.is_a?(String) && id.match?(/\A[a-z][a-z0-9_]{1,40}\z/)
        raise ArgumentError, 'Thông tin cầu nối không hợp lệ.' unless info.is_a?(Hash) && info[:provides].is_a?(Array) && info[:commands].is_a?(Hash) && info[:commands].values.all? { |c| c.respond_to?(:call) }
        providers[id] = info
      end

      # Plugin cung cấp loại đối tượng này với đúng phiên bản cầu nối; không có thì nil.
      def provider_for(kind)
        found = providers.find { |_id, info| info[:bridge_version] == VERSION && info[:provides].include?(kind) }
        found && {id: found[0], info: found[1]}
      end

      def call(kind, command, *args)
        provider = provider_for(kind)
        raise "Chưa cài plugin dựng #{kind}. Hãy cài qua VGD Center." unless provider
        callable = provider[:info][:commands][command]
        raise "Plugin #{provider[:id]} không có lệnh #{command}." unless callable
        callable.call(*args)
      end
    end
  end
end
