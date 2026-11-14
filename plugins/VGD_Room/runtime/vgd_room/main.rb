require_relative 'bridge_registry'
require_relative 'builder'

module VGD
  module Room
    # Đăng ký với danh bạ cầu nối: VGD_BIM gọi 'build' để dựng / dựng lại khối phòng và 'find' để tìm khối đã dựng (docs/vgd_bim/BRIDGE.md).
    VGD::Bridge.register('vgd_room', {
      bridge_version: 1, version: VERSION, provides: ['room_volume'],
      commands: {
        'build' => ->(model, room, vgd_id) { Builder.build(model, room, vgd_id) },
        'find' => ->(model, room_id) { Builder.find(model, room_id) }
      }
    })
  end
end
