# Test chụp ảnh món đồ (VGD::BIM::UI::Capture) bằng SketchUp giả lập: góc nhìn / kiểu hiển thị theo preset,
# và trạng thái model phải được trả lại nguyên vẹn. Chạy: ruby dev/test_capture.rb
require 'json'
require 'tmpdir'
require 'fileutils'
module VGD; module BIM; def self.log(m); end; end; end
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_capture')
PNG_BYTES = ("\x89PNG\r\n\x1A\n".b + 'anh chup'.b).freeze

module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
    def length; Math.sqrt(x * x + y * y + z * z); end
    def normalize; l = length; Vector3d.new(x / l, y / l, z / l); end
    def to_a; [x, y, z]; end
  end
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z); @x = x.to_f; @y = y.to_f; @z = z.to_f; end
    def offset(v, d); Point3d.new(x + v.x * d, y + v.y * d, z + v.z * d); end
    def to_a; [x, y, z]; end
    def ==(o); o.respond_to?(:to_a) && to_a == o.to_a; end
  end
end
module Sketchup
  class Color
    def initialize(*parts); @parts = parts; end
    def to_s; "color#{@parts}"; end
  end
  class Camera
    attr_accessor :eye, :target, :up, :fov, :height
    attr_writer :perspective
    def initialize(eye, target, up); @eye = eye; @target = target; @up = up; @perspective = true; @fov = 35.0; @height = 100.0; end
    def perspective?; @perspective; end
  end
  class Entity
    attr_accessor :hidden, :pid
    def initialize(pid); @pid = pid; @hidden = false; end
    def persistent_id; @pid; end
    def hidden?; @hidden; end
    def valid?; true; end
    def bounds; Struct.new(:center, :diagonal).new(Geom::Point3d.new(10, 20, 30), 40.0); end
  end
end
class FakeSelection < Array
  def add(*items); items.flatten.each { |i| self << i }; end
end
class FakeOptions
  def initialize(values); @values = values; end
  def [](key); @values[key]; end
  def []=(key, value); @values[key] = value; end
  def each_key; @values.keys.each; end
end
class FakeView
  attr_accessor :camera, :zoomed, :writes, :fail_next, :fail_on_call, :states
  def initialize(model); @model = model; @camera = Sketchup::Camera.new(Geom::Point3d.new(0, 0, 100), Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1)); @writes = []; @zoomed = []; @states = []; end
  def refresh; end
  def zoom(entity); @zoomed << entity; end
  def write_image(options)
    return false if @fail_next || (@fail_on_call && @writes.size + 1 == @fail_on_call)
    @writes << options
    @states << {hidden: @model.all.select(&:hidden).map(&:pid), selection: @model.selection.map(&:pid), eye: @camera.eye.to_a, target: @camera.target.to_a, options: @model.rendering_options.instance_variable_get(:@values).dup}
    File.binwrite(options[:filename], PNG_BYTES)
    true
  end
end
ORIGINAL_OPTIONS = {'BackgroundColor' => 'sky', 'DrawGround' => true, 'DrawHorizon' => true, 'RenderMode' => 2, 'DisplayColorByLayer' => true}.freeze
class FakeModel
  attr_reader :all, :selection, :rendering_options, :active_view, :ops, :guid
  def initialize(all); @all = all; @selection = FakeSelection.new; @rendering_options = FakeOptions.new(ORIGINAL_OPTIONS.dup); @active_view = FakeView.new(self); @ops = []; @guid = 'MODEL-1'; end
  def start_operation(name, disable_ui = false); @snapshot = @all.map { |e| [e, e.hidden] }; @ops << :start; true; end
  def abort_operation; @snapshot.each { |e, hidden| e.hidden = hidden }; @ops << :abort; end
  def commit_operation; @ops << :commit; end
end
module VGD; module BIM; module Table
  def self.isolate(model, path)
    raise ArgumentError, 'Đối tượng nằm trong thành phần dùng chung nhiều nơi nên không cô lập được.' if path.last.pid == 666
    hidden = model.all.reject { |e| e == path.last || e.hidden }
    hidden.each { |e| e.hidden = true }
    hidden
  end
end; end; end
%w[storage settings images preset].each { |f| require File.expand_path("../runtime/vgd_bim/core/#{f}.rb", __dir__) }
require File.expand_path('../runtime/vgd_bim/ui/capture.rb', __dir__)
C = VGD::BIM::UI::Capture
I = VGD::BIM::Images
D = VGD::BIM::Preset::DEFAULT_SETTINGS
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?(text = nil); yield; false; rescue ArgumentError, RuntimeError => e; text ? e.message.downcase.include?(text) : true; end
def near?(a, b); a.zip(b).all? { |x, y| (x - y).abs < 1e-6 }; end

def world
  items = [Sketchup::Entity.new(11), Sketchup::Entity.new(12), Sketchup::Entity.new(13)]
  model = FakeModel.new(items)
  model.selection.add(items[0], items[1])
  [model, items]
end
def shoot(settings, item = 0)
  model, items = world
  result = C.shoot(model, {entity: items[item], path: [items[item]]}, D.merge(settings))
  [model, items, model.active_view, result]
end

# ---- Góc nhìn Iso: cô lập, đặt camera chéo, zoom, chụp ảnh đúng cỡ ----
model, items, view, result = shoot('image_view' => 'isometric')
original_eye = [0.0, 0.0, 100.0]
check 'trả về mã đối tượng và dấu thời gian của ảnh mới', result[:pid] == 11 && result[:stamp] > 0
check 'ghi 2 ảnh: ảnh đầy đủ và ảnh nhỏ', view.writes.size == 2
check 'ảnh đầy đủ đúng cỡ trong preset, nền trong suốt, khử răng cưa', view.writes[0].values_at(:width, :height, :transparent, :antialias) == [512, 512, true, true]
check 'ảnh nhỏ giữ tỉ lệ ảnh đầy đủ, cạnh dài đúng cỡ thumbnail', view.writes[1].values_at(:width, :height) == [C::THUMB_SIZE, C::THUMB_SIZE]
check 'Iso: khi chụp camera nhìn vào tâm món đồ từ phía trước-phải-trên (1, -1, 0.8)', view.states.all? { |s| s[:target] == [10.0, 20.0, 30.0] && near?(s[:eye].zip([10.0, 20.0, 30.0]).map { |e, c| e - c }.then { |d| l = Math.sqrt(d.sum { |v| v * v }); d.map { |v| v / l } }, Geom::Vector3d.new(1, -1, 0.8).normalize.to_a) }
check 'Iso: camera đặt cách tâm đủ xa so với món đồ (không nằm trong món đồ), rồi zoom cho vừa', view.states.all? { |s| Math.sqrt(s[:eye].zip([10, 20, 30]).sum { |e, c| (e - c)**2 }) > 40.0 } && view.zoomed == [items[0]]
check 'Iso: các món khác bị ẩn, món cần chụp hiện, không còn đối tượng chọn (khỏi lẫn khung chọn vào ảnh)', view.states.all? { |s| s[:hidden].sort == [12, 13] && s[:selection].empty? }
check 'Iso: model chỉ mở một thao tác và hủy (abort) nên không để lại bước undo, không commit', model.ops == [:start, :abort]
check 'sau khi chụp: không còn gì bị ẩn, camera như cũ, lựa chọn như cũ', items.none?(&:hidden) && view.camera.eye.to_a == original_eye && model.selection.map(&:pid) == [11, 12]
check 'file ảnh đầy đủ và ảnh nhỏ nằm đúng chỗ, không còn file tạm', File.binread(I.path(model, 11)) == PNG_BYTES && File.binread(I.path(model, 11, :thumb)) == PNG_BYTES && Dir[File.join(I.dir(model), '*')].none? { |f| f.include?('.tmp') }

# ---- Cỡ ảnh theo preset (rộng x cao riêng) ----
_, _, view, _ = shoot('image_view' => 'isometric', 'image_width' => 640, 'image_height' => 480)
check 'cỡ ảnh theo preset: 640 x 480, ảnh nhỏ 128 x 96 (giữ tỉ lệ)', view.writes[0].values_at(:width, :height) == [640, 480] && view.writes[1].values_at(:width, :height) == [128, 96]
_, _, view, _ = shoot('image_view' => 'isometric', 'image_width' => 300, 'image_height' => 900)
check 'ảnh dọc: ảnh nhỏ 43 x 128 (cạnh dài là chiều cao)', view.writes[1].values_at(:width, :height) == [43, 128]

# ---- Góc nhìn chính diện ----
_, _, view, _ = shoot('image_view' => 'front')
check 'Chính diện: camera nằm phía -Y của tâm, nhìn vào tâm, cùng độ cao với tâm', view.states.all? { |s| s[:target] == [10.0, 20.0, 30.0] && (s[:eye][0] - 10.0).abs < 1e-6 && s[:eye][1] < 20.0 && (s[:eye][2] - 30.0).abs < 1e-6 }

# ---- Khung nhìn hiện tại: không đổi gì, chụp đúng cỡ preset ----
model, items, view, _ = shoot('image_view' => 'current', 'image_width' => 800, 'image_height' => 400)
check 'Hiện tại: không mở thao tác, không ẩn gì, không zoom, camera không đổi', model.ops.empty? && view.zoomed.empty? && view.states.all? { |s| s[:hidden].empty? && s[:eye] == original_eye }
check 'Hiện tại: ảnh đúng cỡ trong preset (800 x 400)', view.writes[0].values_at(:width, :height) == [800, 400]
check 'Hiện tại: vẫn bỏ chọn khi chụp rồi trả lại', view.states.all? { |s| s[:selection].empty? } && model.selection.map(&:pid) == [11, 12]

# ---- Kiểu hiển thị ----
model, _, view, _ = shoot('image_view' => 'current', 'image_style' => 'color')
check 'kiểu Màu: khi chụp dùng chế độ shaded có texture và tắt tô màu theo tag', view.states.all? { |s| s[:options]['RenderMode'] == 3 && s[:options]['DisplayColorByLayer'] == false }
check 'kiểu Màu: sau khi chụp trả lại đúng tuỳ chọn hiển thị cũ', model.rendering_options.instance_variable_get(:@values) == ORIGINAL_OPTIONS
model, _, view, _ = shoot('image_view' => 'current', 'image_style' => 'current')
check 'kiểu Hiện tại: không đổi tuỳ chọn hiển thị nào', view.states.all? { |s| s[:options] == ORIGINAL_OPTIONS }

# ---- Nền trắng ----
model, _, view, _ = shoot('image_view' => 'isometric', 'image_style' => 'color', 'image_background' => 'white')
check 'nền trắng: không dùng nền trong suốt', view.writes.all? { |w| w[:transparent] == false }
check 'nền trắng: tạm đổi màu nền, tắt mặt đất và chân trời (cùng kiểu Màu)', view.states.all? { |s| s[:options]['BackgroundColor'].to_s != 'sky' && s[:options]['DrawGround'] == false && s[:options]['DrawHorizon'] == false && s[:options]['RenderMode'] == 3 }
check 'nền trắng + kiểu Màu: sau khi chụp trả lại đúng toàn bộ tuỳ chọn cũ', model.rendering_options.instance_variable_get(:@values) == ORIGINAL_OPTIONS

# ---- Lỗi giữa chừng: trạng thái model phải được trả lại ----
model, items = world
view = model.active_view
I.write(model, 11, PNG_BYTES + 'cu'.b, PNG_BYTES)
view.fail_next = true
check 'SketchUp không ghi được ảnh: báo lỗi', raises?('chụp') { C.shoot(model, {entity: items[0], path: [items[0]]}, D.merge('image_background' => 'white')) }
check 'lỗi giữa chừng: hủy thao tác, không còn gì bị ẩn, camera, lựa chọn, tuỳ chọn hiển thị như cũ', model.ops == [:start, :abort] && items.none?(&:hidden) && view.camera.eye.to_a == original_eye && model.selection.map(&:pid) == [11, 12] && model.rendering_options.instance_variable_get(:@values) == ORIGINAL_OPTIONS
check 'lỗi giữa chừng: ảnh cũ còn nguyên, không còn file tạm', File.binread(I.path(model, 11)).end_with?('cu') && Dir[File.join(I.dir(model), '*')].none? { |f| f.include?('.tmp') }
model, items = world
view = model.active_view
I.write(model, 11, PNG_BYTES + 'cu'.b, PNG_BYTES)
view.fail_on_call = 2
check 'ảnh nhỏ lỗi sau khi ảnh đầy đủ đã chụp: báo lỗi', raises?('chụp') { C.shoot(model, {entity: items[0], path: [items[0]]}, D) }
check 'ảnh nhỏ lỗi: không còn file tạm, cả hai ảnh cũ còn nguyên (không ghi nửa chừng)', Dir[File.join(I.dir(model), '*')].none? { |f| f.include?('.tmp') } && File.binread(I.path(model, 11)).end_with?('cu') && File.binread(I.path(model, 11, :thumb)) == PNG_BYTES && items.none?(&:hidden)
model, items = world
bad = Sketchup::Entity.new(666)
check 'không cô lập được (thành phần dùng chung): báo lỗi rõ, không chụp, trả lại mọi thứ', raises?('dùng chung') { C.shoot(model, {entity: bad, path: [bad]}, D.merge('image_style' => 'color')) } && model.active_view.writes.empty? && model.ops == [:start, :abort] && model.selection.map(&:pid) == [11, 12] && model.rendering_options.instance_variable_get(:@values) == ORIGINAL_OPTIONS
model, items = world
check 'không cô lập được nhưng chọn Hiện tại thì vẫn chụp được', (C.shoot(model, {entity: bad, path: [bad]}, D.merge('image_view' => 'current')); model.active_view.writes.size == 2)

# ---- Chặn dữ liệu sai ----
model, items = world
check 'đối tượng đã bị xóa: báo lỗi, không chụp', raises?('không còn') { gone = Sketchup::Entity.new(20); gone.define_singleton_method(:valid?) { false }; C.shoot(model, {entity: gone, path: [gone]}, D) } && model.ops.empty?
check 'đối tượng chưa có mã bền (persistent_id) bị từ chối', raises? { C.shoot(model, {entity: Sketchup::Entity.new(0), path: []}, D) }
check 'thiết lập sai (góc nhìn lạ) bị từ chối, không chụp', raises?('góc nhìn') { C.shoot(model, {entity: items[0], path: [items[0]]}, D.merge('image_view' => 'top')) } && model.active_view.writes.empty? && model.ops.empty?
