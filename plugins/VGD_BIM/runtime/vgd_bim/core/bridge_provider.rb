module VGD
  module BIM
    # VGD_BIM đăng ký vào danh bạ cầu nối với loại `vgd_id`: plugin dựng hình (VGD Structure...) xin VGD ID mới qua lệnh `generate` để mọi đối tượng
    # dùng chung một nguồn cấp ID (docs/vgd_bim/BRIDGE.md mục 2). Chạy lại khi tải lại code thì ghi đè mục cũ, không nhân đôi.
    module BridgeProvider
      def self.register
        ::VGD::Bridge.register('vgd_bim', {bridge_version: ::VGD::Bridge::VERSION, version: VERSION, provides: ['vgd_id'], commands: {'generate' => -> { VgdId.generate }}})
      end
    end
    BridgeProvider.register
  end
end
