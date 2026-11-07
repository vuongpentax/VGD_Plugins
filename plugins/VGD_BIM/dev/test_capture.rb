# Test chụp ảnh món đồ (VGD::BIM::UI::Capture) bằng SketchUp giả lập: trạng thái model phải được trả lại nguyên vẹn.
# Chạy: ruby dev/test_capture.rb
require 'json'
require 'tmpdir'
require 'fileutils'
module VGD; module BIM; def self.log(m); end; end; end
ENV['VGD_BIM_DATA_DIR'] = Dir.mktmpdir('vgd_bim_capture')
PNG_BYTES = ("\x89PNG\r\n\x1A\n".b + 'anh chup'.b).freeze

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
  def initialize(model); @model = model; @camera = Sketchup::Camera.new([0, 0, 100], [0, 0, 0], [0, 0, 1]); @writes = []; @zoomed = []; @states = []; end
  def vpwidth; 1000; end
  def vpheight; 500; end
  def refresh; end
  def zoom(entity); @zoomed << entity; @camera = Sketchup::Camera.new([5, 5, 5], [1, 1, 1], [0, 0, 1]); end
  def write_image(options)
    return false if @fail_next || (@fail_on_call && @writes.size + 1 == @fail_on_call)
    @writes << options
    @states << {hidden: @model.all.select(&:hidden).map(&:pid), selection: @model.selection.map(&:pid), camera: @camera.eye.dup, options: @model.rendering_options.instance_variable_get(:@values).dup}
    File.binwrite(options[:filename], PNG_BYTES)
    true
  end
end
class FakeModel
  attr_reader :all, :selection, :rendering_options, :active_view, :ops, :guid
  def initialize(all); @all = all; @selection = FakeSelection.new; @rendering_options = FakeOptions.new('BackgroundColor' => 'sky', 'DrawGround' => true, 'DrawHorizon' => true); @active_view = FakeView.new(self); @ops = []; @guid = 'MODEL-1'; end
  def start_operation(name, disable_ui = false); @snapshot = @all.map { |e| [e, e.hidden] }; @ops << :start; true; end
  def abort_operation; @snapshot.each { |e, hidden| e.hidden = hidden }; @ops << :abort; end
  def commit_operation; @ops << :commit; end
  def active_view; @active_view; end
end
module VGD; module BIM; module Table
  def self.isolate(model, path)
    raise ArgumentError, 'Đối tượng nằm trong thành phần dùng chung nhiều nơi nên không cô lập được.' if path.last.pid == 666
    hidden = model.all.reject { |e| e == path.last || e.hidden }
    hidden.each { |e| e.hidden = true }
    hidden
  end
end; end; end
%w[storage settings images].each { |f| require File.expand_path("../runtime/vgd_bim/core/#{f}.rb", __dir__) }
require File.expand_path('../runtime/vgd_bim/ui/capture.rb', __dir__)
C = VGD::BIM::UI::Capture
I = VGD::BIM::Images
S = VGD::BIM::Settings
def check(label, cond); puts "#{cond ? 'PASS' : 'FAIL'}  #{label}"; end
def raises?(text = nil); yield; false; rescue ArgumentError, RuntimeError => e; text ? e.message.downcase.include?(text) : true; end

def world
  items = [Sketchup::Entity.new(11), Sketchup::Entity.new(12), Sketchup::Entity.new(13)]
  model = FakeModel.new(items)
  model.selection.add(items[0], items[1])
  [model, items]
end

# ---- Cô lập: chụp riêng món đồ ----
model, items = world
view = model.active_view
original_eye = view.camera.eye.dup
record = {entity: items[0], path: [items[0]]}
result = C.shoot(model, record, S.read)
check 'trả về mã đối tượng và dấu thời gian của ảnh mới', result[:pid] == 11 && result[:stamp] > 0
check 'ghi 2 ảnh: ảnh đầy đủ và ảnh nhỏ', view.writes.size == 2
check 'ảnh đầy đủ: vuông, đúng cỡ trong cài đặt, nền trong suốt, khử răng cưa', view.writes[0].values_at(:width, :height, :transparent, :antialias) == [512, 512, true, true]
check 'ảnh nhỏ: cạnh dài đúng cỡ thumbnail', view.writes[1].values_at(:width, :height) == [C::THUMB_SIZE, C::THUMB_SIZE]
check 'khi chụp: các món khác bị ẩn, món cần chụp hiện', view.states.all? { |s| s[:hidden].sort == [12, 13] }
check 'khi chụp: đã zoom vào món đồ, không còn đối tượng đang chọn (khỏi lẫn khung chọn vào ảnh)', view.zoomed == [items[0]] && view.states.all? { |s| s[:selection].empty? }
check 'model chỉ mở một thao tác và hủy (abort) nên không để lại bước undo, không commit', model.ops == [:start, :abort]
check 'sau khi chụp: không còn đối tượng nào bị ẩn', items.none?(&:hidden)
check 'sau khi chụp: camera trở lại đúng như cũ', view.camera.eye == original_eye && view.camera.target == [0, 0, 0] && view.camera.perspective?
check 'sau khi chụp: lựa chọn trong SketchUp trở lại như cũ', model.selection.map(&:pid) == [11, 12]
check 'file ảnh đầy đủ và ảnh nhỏ đã nằm đúng chỗ, không còn file tạm', File.binread(I.path(model, 11)) == PNG_BYTES && File.binread(I.path(model, 11, :thumb)) == PNG_BYTES && Dir[File.join(I.dir(model), '*')].none? { |f| f.include?('.tmp') }

# ---- Nền trắng ----
model, items = world
S.update('image_background' => 'white')
C.shoot(model, {entity: items[0], path: [items[0]]}, S.read)
view = model.active_view
check 'nền trắng: không dùng nền trong suốt', view.writes.all? { |w| w[:transparent] == false }
check 'nền trắng: khi chụp tạm đổi màu nền, tắt mặt đất và chân trời', view.states.all? { |s| s[:options]['BackgroundColor'].to_s != 'sky' && s[:options]['DrawGround'] == false && s[:options]['DrawHorizon'] == false }
check 'nền trắng: sau khi chụp trả lại đúng tuỳ chọn hiển thị cũ', model.rendering_options.instance_variable_get(:@values) == {'BackgroundColor' => 'sky', 'DrawGround' => true, 'DrawHorizon' => true}
S.update('image_background' => 'transparent')

# ---- Chụp đúng khung nhìn hiện tại ----
model, items = world
S.update('capture_mode' => 'current', 'image_size' => 800)
view = model.active_view
original_eye = view.camera.eye.dup
C.shoot(model, {entity: items[1], path: [items[1]]}, S.read)
check 'khung nhìn hiện tại: không mở thao tác, không ẩn gì, không zoom', model.ops.empty? && view.zoomed.empty? && view.states.all? { |s| s[:hidden].empty? }
check 'khung nhìn hiện tại: giữ tỉ lệ khung nhìn (1000x500 -> 800x400) và camera không đổi', view.writes[0].values_at(:width, :height) == [800, 400] && view.camera.eye == original_eye
check 'khung nhìn hiện tại: vẫn bỏ chọn khi chụp rồi trả lại', view.states.all? { |s| s[:selection].empty? } && model.selection.map(&:pid) == [11, 12]
S.update('capture_mode' => 'isolate', 'image_size' => 512)

# ---- Lỗi giữa chừng: trạng thái model phải được trả lại ----
model, items = world
view = model.active_view
original_eye = view.camera.eye.dup
I.write(model, 11, PNG_BYTES + 'cu'.b, PNG_BYTES)
view.fail_next = true
check 'SketchUp không ghi được ảnh: báo lỗi', raises?('chụp') { C.shoot(model, {entity: items[0], path: [items[0]]}, S.read) }
check 'lỗi giữa chừng: hủy thao tác, không còn gì bị ẩn, camera và lựa chọn như cũ', model.ops == [:start, :abort] && items.none?(&:hidden) && view.camera.eye == original_eye && model.selection.map(&:pid) == [11, 12]
check 'lỗi giữa chừng: ảnh cũ còn nguyên, không còn file tạm', File.binread(I.path(model, 11)).end_with?('cu') && Dir[File.join(I.dir(model), '*')].none? { |f| f.include?('.tmp') }
view.fail_next = false

model, items = world
view = model.active_view
I.write(model, 11, PNG_BYTES + 'cu'.b, PNG_BYTES)
view.fail_on_call = 2 # ảnh đầy đủ chụp xong (đã có file tạm) nhưng ảnh nhỏ lỗi
check 'ảnh nhỏ lỗi sau khi ảnh đầy đủ đã chụp: báo lỗi', raises?('chụp') { C.shoot(model, {entity: items[0], path: [items[0]]}, S.read) }
check 'ảnh nhỏ lỗi: không còn file tạm, cả hai ảnh cũ còn nguyên (không ghi nửa chừng)', Dir[File.join(I.dir(model), '*')].none? { |f| f.include?('.tmp') } && File.binread(I.path(model, 11)).end_with?('cu') && File.binread(I.path(model, 11, :thumb)) == PNG_BYTES && items.none?(&:hidden)

model, items = world
bad = Sketchup::Entity.new(666)
check 'không cô lập được (thành phần dùng chung): báo lỗi rõ, không chụp, không đổi gì', raises?('dùng chung') { C.shoot(model, {entity: bad, path: [bad]}, S.read) } && model.active_view.writes.empty? && model.ops == [:start, :abort] && model.selection.map(&:pid) == [11, 12]

# ---- Chặn dữ liệu sai ----
model, items = world
check 'đối tượng đã bị xóa: báo lỗi, không chụp', raises?('không còn') { gone = Sketchup::Entity.new(20); gone.define_singleton_method(:valid?) { false }; C.shoot(model, {entity: gone, path: [gone]}, S.read) } && model.ops.empty?
check 'đối tượng chưa có mã bền (persistent_id) bị từ chối', raises? { C.shoot(model, {entity: Sketchup::Entity.new(0), path: []}, S.read) }
