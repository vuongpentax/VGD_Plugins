# Zoom Extents: lớp phủ vẽ ảnh trong không gian màn hình nên không được đóng góp vùng 3D.
# Trước đây getExtents trả Sketchup.active_model.bounds; hộp này gồm cả đối tượng đã ẩn/tắt tag nên
# Zoom Extents vẫn nhìn ra cả vùng đã ẩn. Chạy riêng: ruby dev/overlay_extents_fixture.rb (từ plugins/VGD_Reference).
unless defined?(Sketchup::Overlay)
  module Sketchup
    class Overlay
      def initialize(*); end
    end
  end
end
unless defined?(Geom::BoundingBox)
  module Geom
    class BoundingBox
      def initialize; @pts = []; end
      def add(*points); @pts.concat(points); self; end
      def empty?; @pts.empty?; end
    end
  end
end
module Sketchup
  def self.active_model
    # Mô hình có một đối tượng đã ẩn ở rất xa: model.bounds vẫn tính đối tượng này.
    @fixture_model ||= Class.new do
      def bounds; Geom::BoundingBox.new.add([0, 0, 0], [99_999, 99_999, 99_999]); end
    end.new
  end
end
root = File.expand_path('../runtime/vgd_reference', __dir__)
require File.join(root, 'core/constants')
require File.join(root, 'viewport/reference_overlay')
extents = VGD::Reference::ReferenceOverlay.new.getExtents
raise 'getExtents trả hộp bao của cả model (gồm đối tượng đã ẩn): Zoom Extents sẽ tính cả vùng đã ẩn.' unless extents.respond_to?(:empty?) && extents.empty?
puts 'PASS: overlay không đóng góp vùng 3D cho Zoom Extents (không tính đối tượng đã ẩn).'
