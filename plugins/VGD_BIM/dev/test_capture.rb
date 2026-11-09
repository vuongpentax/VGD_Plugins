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
    def fov_is_height?; false; end
    def direction; d = target.to_a.zip(eye.to_a).map { |t, e| t - e }; l = Math.sqrt(d.sum { |v| v * v }); Geom::Vector3d.new(*d.map { |v| v / l }); end
    def set(new_eye, new_target, new_up); @eye = new_eye; @target = new_target; @up = new_up; end
  end
  class Entity
    attr_accessor :hidden, :pid, :definition
    def initialize(pid); @pid = pid; @hidden = false; end
    def persistent_id; @pid; end
    def hidden?; @hidden; end
    def valid?; true; end
    # Món cao 200 (hộp bao từ (-40, 0, -70) tới (60, 40, 130), tâm (10, 20, 30)); diagonal chỉ dùng để đặt camera thô lúc đầu
    def bounds; Struct.new(:center, :diagonal, :min, :max) { def empty?; false; end }.new(Geom::Point3d.new(10, 20, 30), 40.0, Geom::Point3d.new(-40, 0, -70), Geom::Point3d.new(60, 40, 130)); end
  end
end
class FakeSelection < Array
  # SketchUp thật báo lỗi khi gọi add mà không truyền đối tượng nào.
  def add(*items); raise ArgumentError, 'wrong number of arguments (given 0, expected 1+)' if items.empty?; items.flatten.each { |i| self << i }; end
end
class FakeOptions
  def initialize(values); @values = values; end
  def [](key); @values[key]; end
  def []=(key, value); @values[key] = value; end
  # SketchUp thật: each_key chỉ chạy với khối, gọi không khối báo LocalJumpError (lỗi gặp trong capture.log của người dùng)
  def each_key(&block); raise LocalJumpError, 'no block given' unless block; @values.keys.each(&block); end
end
class FakeView
  attr_accessor :vpwidth, :vpheight, :camera, :zoomed, :writes, :fail_next, :fail_on_call, :states, :reject_transparent, :raise_on_transparent, :attempts, :reject_all_options
  def initialize(model); @model = model; @camera = Sketchup::Camera.new(Geom::Point3d.new(0, 0, 100), Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1)); @writes = []; @zoomed = []; @states = []; @vpwidth = 1000; @vpheight = 500; end
  def refresh; end
  def zoom(entity); @zoomed << entity; end
  def write_image(options)
    (@attempts ||= []) << options.dup
    raise ArgumentError, 'Invalid option: transparent' if @raise_on_transparent && options[:transparent]
    return false if @reject_transparent && options[:transparent]
    return false if @reject_all_options && options[:antialias]
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
module VGD; module BIM; module Geometry
  def self.definition(entity); entity.definition; end
  def self.world_bounds(records); records.first[:entity].bounds; end # giả lập: model ở gốc nên hộp bao thế giới = hộp bao của đối tượng
end; end; end
module VGD; module BIM; module Table
  def self.isolate(model, path)
    raise ArgumentError, 'Đối tượng nằm trong thành phần dùng chung nhiều nơi nên không cô lập được.' if path.last.pid == 666
    hidden = model.all.reject { |e| e == path.last || e.hidden }
    hidden.each { |e| e.hidden = true }
    hidden
  end
end; end; end
%w[storage settings images preset front front_probe view_fit].each { |f| require File.expand_path("../runtime/vgd_bim/core/#{f}.rb", __dir__) }
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
check 'chỉ ghi 1 ảnh (ảnh đầy đủ, không còn ảnh nhỏ nên chụp nhanh hơn)', view.writes.size == 1
check 'ảnh đầy đủ đúng cỡ trong preset, nền trong suốt, khử răng cưa', view.writes[0].values_at(:width, :height, :transparent, :antialias) == [512, 512, true, true]
check 'Iso: khi chụp camera nhìn vào tâm món đồ từ phía trước-phải-trên (1, -1, 0.8)', view.states.all? { |s| s[:target] == [10.0, 20.0, 30.0] && near?(s[:eye].zip([10.0, 20.0, 30.0]).map { |e, c| e - c }.then { |d| l = Math.sqrt(d.sum { |v| v * v }); d.map { |v| v / l } }, Geom::Vector3d.new(1, -1, 0.8).normalize.to_a) }
check 'Iso: camera đặt cách tâm đủ xa so với món đồ (không nằm trong món đồ)', view.states.all? { |s| Math.sqrt(s[:eye].zip([10, 20, 30]).sum { |e, c| (e - c)**2 }) > 40.0 }
radius = Math.sqrt(50.0**2 + 20.0**2 + 100.0**2)
half_narrow = 35.0 * Math::PI / 360.0 # ảnh vuông (512 x 512): góc hẹp hơn là góc ngang 35 độ
need = radius / Math.sin(half_narrow)
dist = ->(s) { Math.sqrt(s[:eye].zip(s[:target]).sum { |e, t| (e - t)**2 }) }
wide_half = Math.atan(Math.tan(half_narrow) / 2.0) # khung nhìn 1000 x 500 (tỉ lệ 2:1) với fov ngang 35 độ: góc dọc hẹp hơn nên phải lùi xa hơn
need_wide = radius / Math.sin(wide_half)
check 'Iso: lùi xa thêm một bước (extend) theo hộp bao thật của món cao 200 và tỉ lệ khung nhìn 2:1 (dọc hẹp hơn): cả hình cầu bao món lọt trong góc nhìn có chừa lề 20%, nên không bị cắt', view.states.all? { |s| dist.(s) >= need_wide * 1.15 && dist.(s) <= need_wide * 1.25 } && view.zoomed.empty?
sq_model, sq_items = world
sq_model.active_view.vpwidth = 500
sq_model.active_view.vpheight = 500
C.shoot(sq_model, {entity: sq_items[0], path: [sq_items[0]]}, D.merge('image_view' => 'isometric'))
check 'ảnh vuông và khung nhìn vuông: không cần lùi xa như khi khung nhìn dẹt (đúng góc ngang 35 độ)', sq_model.active_view.states.all? { |s| dist.(s) >= need * 1.15 && dist.(s) <= need * 1.25 }
check 'Iso: các món khác bị ẩn, món cần chụp hiện, không còn đối tượng chọn (khỏi lẫn khung chọn vào ảnh)', view.states.all? { |s| s[:hidden].sort == [12, 13] && s[:selection].empty? }
check 'Iso: model chỉ mở một thao tác và hủy (abort) nên không để lại bước undo, không commit', model.ops == [:start, :abort]
check 'sau khi chụp: không còn gì bị ẩn, camera như cũ, lựa chọn như cũ', items.none?(&:hidden) && view.camera.eye.to_a == original_eye && model.selection.map(&:pid) == [11, 12]
check 'file ảnh đầy đủ nằm đúng chỗ, không có ảnh nhỏ và không còn file tạm', File.binread(I.path(model, 11)) == PNG_BYTES && Dir[File.join(I.dir(model), '*')].map { |f| File.basename(f) } == ['11.png']

# ---- Cỡ ảnh theo preset (rộng x cao riêng) ----
_, _, view, _ = shoot('image_view' => 'isometric', 'image_width' => 640, 'image_height' => 480)
check 'cỡ ảnh theo preset: 640 x 480', view.writes[0].values_at(:width, :height) == [640, 480]
_, _, view, _ = shoot('image_view' => 'isometric', 'image_width' => 300, 'image_height' => 900)
check 'ảnh dọc theo preset: 300 x 900', view.writes[0].values_at(:width, :height) == [300, 900]
_, _, view_m0, _ = shoot('image_view' => 'isometric', 'image_margin' => 0)
_, _, view_m50, _ = shoot('image_view' => 'isometric', 'image_margin' => 50)
check 'lề ảnh theo thiết lập: 0% ôm sát hộp bao (xa đúng tỉ lệ 1,0), 50% lùi xa hơn đúng tỉ lệ 1,5 / 1,0 so với 0%', near?([dist.(view_m50.states[0]) / dist.(view_m0.states[0])], [1.5]) && dist.(view_m0.states[0]) >= need_wide * 0.999
model_l, items_l = world
C.shoot(model_l, {entity: items_l[0], path: [items_l[0]]}, D.merge('image_view' => 'isometric'), iso_side: 'left')
model_r, items_r = world
C.shoot(model_r, {entity: items_r[0], path: [items_r[0]]}, D.merge('image_view' => 'isometric'), iso_side: 'right')
dir_l = model_l.active_view.states[0][:eye].zip(model_l.active_view.states[0][:target]).map { |e, t| e - t }
dir_r = model_r.active_view.states[0][:eye].zip(model_r.active_view.states[0][:target]).map { |e, t| e - t }
check 'Iso bên trái (món chưa có mặt trước, theo trục thế giới): camera ở phía -X, đối xứng với bên phải ở +X; cao và xa như nhau', dir_l[0] < 0 && dir_r[0] > 0 && (dir_l[0] + dir_r[0]).abs < 1e-6 && (dir_l[1] - dir_r[1]).abs < 1e-6 && (dir_l[2] - dir_r[2]).abs < 1e-6
check 'bên Iso lạ bị từ chối trước khi chụp', raises?('bên') { C.shoot(world[0], {entity: world[1][0], path: [world[1][0]]}, D, iso_side: 'giữa') }
_, _, view_wide, _ = shoot('image_view' => 'isometric', 'image_width' => 800, 'image_height' => 400)
_, _, view_tall, _ = shoot('image_view' => 'isometric', 'image_width' => 400, 'image_height' => 800)
check 'ảnh ngang 800 x 400: lùi theo góc dọc hẹp hơn, xa hơn ảnh vuông (món cao không bị cắt trên dưới)', view_wide.states.all? { |st| dist.(st) >= need_wide * 1.15 && dist.(st) <= need_wide * 1.25 } && dist.(view_wide.states[0]) > need * 1.4
check 'ảnh dọc 400 x 800 mà khung nhìn đang ngang 1000 x 500: lấy khoảng cách an toàn nhất của hai tỉ lệ (ảnh và khung nhìn), nên không ngắn hơn ảnh ngang', (dist.(view_tall.states[0]) - dist.(view_wide.states[0])).abs < 1e-6

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
I.write(model, 11, PNG_BYTES + 'cu'.b)
view.fail_next = true
check 'SketchUp không ghi được ảnh: báo lỗi', raises?('không chụp được') { C.shoot(model, {entity: items[0], path: [items[0]]}, D.merge('image_background' => 'white')) }
check 'lỗi giữa chừng: hủy thao tác, không còn gì bị ẩn, camera, lựa chọn, tuỳ chọn hiển thị như cũ', model.ops == [:start, :abort] && items.none?(&:hidden) && view.camera.eye.to_a == original_eye && model.selection.map(&:pid) == [11, 12] && model.rendering_options.instance_variable_get(:@values) == ORIGINAL_OPTIONS
check 'lỗi giữa chừng: ảnh cũ còn nguyên, không còn file tạm', File.binread(I.path(model, 11)).end_with?('cu') && Dir[File.join(I.dir(model), '*')].none? { |f| f.include?('.tmp') }
model, items = world
view = model.active_view
I.write(model, 11, PNG_BYTES + 'cu'.b)
view.fail_on_call = 1
check 'SketchUp không ghi được ảnh: báo lỗi', raises?('không chụp được') { C.shoot(model, {entity: items[0], path: [items[0]]}, D) }
check 'ảnh lỗi: không còn file tạm, ảnh cũ còn nguyên (không ghi nửa chừng)', Dir[File.join(I.dir(model), '*')].none? { |f| f.include?('.tmp') } && File.binread(I.path(model, 11)).end_with?('cu') && items.none?(&:hidden)
model, items = world
bad = Sketchup::Entity.new(666)
check 'không cô lập được (thành phần dùng chung): báo lỗi rõ, không chụp, trả lại mọi thứ', raises?('dùng chung') { C.shoot(model, {entity: bad, path: [bad]}, D.merge('image_style' => 'color')) } && model.active_view.writes.empty? && model.ops == [:start, :abort] && model.selection.map(&:pid) == [11, 12] && model.rendering_options.instance_variable_get(:@values) == ORIGINAL_OPTIONS
model, items = world
check 'không cô lập được nhưng chọn Hiện tại thì vẫn chụp được', (C.shoot(model, {entity: bad, path: [bad]}, D.merge('image_view' => 'current')); model.active_view.writes.size == 1)

# ---- Lỗi thật gặp trong SketchUp: chọn rỗng, tuỳ chọn ảnh không được hỗ trợ ----
FileUtils.rm_f(File.join(VGD::BIM::Storage.dir, 'capture.log'))
model, items = world
model.selection.clear
result = nil
check 'không có đối tượng nào đang chọn: chụp vẫn thành công (SketchUp không nhận Selection#add rỗng)', (result = C.shoot(model, {entity: items[0], path: [items[0]]}, D.merge('image_view' => 'current'))) && result[:pid] == 11 && model.selection.empty?
check 'chọn rỗng: không có lỗi khôi phục nào bị ghi lại (không gọi Selection#add rỗng)', !File.exist?(File.join(VGD::BIM::Storage.dir, 'capture.log')) || !File.read(File.join(VGD::BIM::Storage.dir, 'capture.log'), encoding: 'UTF-8').include?('Khôi phục')
model, items = world
model.selection.clear
check 'chọn rỗng + cô lập: cũng thành công, không còn gì bị ẩn', (C.shoot(model, {entity: items[0], path: [items[0]]}, D)) && items.none?(&:hidden) && model.selection.empty?
model, items = world
view = model.active_view
view.reject_transparent = true
result = C.shoot(model, {entity: items[0], path: [items[0]]}, D)
check 'nền trong suốt bị từ chối (write_image trả false): tự thử lại không trong suốt và vẫn chụp được', view.writes.size == 1 && view.writes.all? { |w| w[:transparent] == false } && File.file?(I.path(model, 11))
check 'chụp bằng cách thay thế: báo cho người dùng biết (nền không trong suốt)', result[:note].to_s.include?('trong suốt')
model, items = world
view = model.active_view
view.raise_on_transparent = true
result = C.shoot(model, {entity: items[0], path: [items[0]]}, D)
check 'tuỳ chọn transparent làm SketchUp báo lỗi: cũng tự thử lại và chụp được', view.writes.size == 1 && result[:pid] == 11 && result[:note].to_s.include?('trong suốt')
model, items = world
view = model.active_view
result = C.shoot(model, {entity: items[0], path: [items[0]]}, D.merge('image_background' => 'white'))
check 'nền trắng (không xin trong suốt): không có ghi chú về cách chụp thay thế và chỉ ghi đúng 1 ảnh', !result[:note].to_s.include?('trong suốt') && view.attempts.size == 1
model, items = world
view = model.active_view
view.reject_transparent = true
view.reject_all_options = true
result = C.shoot(model, {entity: items[0], path: [items[0]]}, D)
check 'chỉ chụp được khi tắt cả khử răng cưa: vẫn thành công, có ghi chú', view.writes.size == 1 && view.writes.all? { |w| w[:antialias] == false } && result[:note].to_s.include?('khử răng cưa')
model, items = world
view = model.active_view
view.fail_next = true
message = begin; C.shoot(model, {entity: items[0], path: [items[0]]}, D); nil; rescue RuntimeError => e; e.message; end
check 'mọi cách chụp đều thất bại: báo lỗi có đường dẫn file, cỡ ảnh và số cách đã thử', message.to_s.include?(I.dir(model)) && message.include?('512') && message.include?('3 cách')
check 'lỗi chụp được ghi vào capture.log để gửi chẩn đoán', File.exist?(File.join(VGD::BIM::Storage.dir, 'capture.log')) && File.read(File.join(VGD::BIM::Storage.dir, 'capture.log'), encoding: 'UTF-8').include?(I.dir(model))
model, items = world
view = model.active_view
values = model.rendering_options.instance_variable_get(:@values)
model.rendering_options.define_singleton_method(:[]=) { |key, value| raise 'tuỳ chọn hiển thị lỗi' if ORIGINAL_OPTIONS[key] == value; values[key] = value }
result = nil
check 'khôi phục tuỳ chọn hiển thị bị lỗi: không biến lần chụp thành công thành thất bại, camera và lựa chọn vẫn được trả lại', (result = C.shoot(model, {entity: items[0], path: [items[0]]}, D.merge('image_style' => 'color'))) && result[:pid] == 11 && view.camera.eye.to_a == [0.0, 0.0, 100.0] && model.selection.map(&:pid) == [11, 12]
model, items = world
dir = I.dir(model)
FileUtils.rm_rf(dir); FileUtils.mkdir_p(File.dirname(dir))
File.write(dir, 'đây là file chứ không phải thư mục') # thư mục ảnh bị file chiếm chỗ
check 'thư mục ảnh không tạo / không ghi được: báo lỗi rõ, không chụp, không đổi model', raises?('thư mục ảnh') { C.shoot(model, {entity: items[0], path: [items[0]]}, D) } && model.ops.empty? && model.active_view.writes.empty?
FileUtils.rm_f(dir)

# ---- Chặn dữ liệu sai ----
model, items = world
check 'đối tượng đã bị xóa: báo lỗi, không chụp', raises?('không còn') { gone = Sketchup::Entity.new(20); gone.define_singleton_method(:valid?) { false }; C.shoot(model, {entity: gone, path: [gone]}, D) } && model.ops.empty?
check 'đối tượng chưa có mã bền (persistent_id) bị từ chối', raises? { C.shoot(model, {entity: Sketchup::Entity.new(0), path: []}, D) }
check 'thiết lập sai (góc nhìn lạ) bị từ chối, không chụp', raises?('góc nhìn') { C.shoot(model, {entity: items[0], path: [items[0]]}, D.merge('image_view' => 'top')) } && model.active_view.writes.empty? && model.ops.empty?

# ---- Chụp theo mặt trước ----
class FrontDef
  def initialize(dir); @a = {}; @a['front'] = dir if dir; end
  def get_attribute(dict, key, default = nil); @a.fetch(key, default); end
end
Axes = Struct.new(:x, :y, :z) do
  def xaxis; Struct.new(:to_a).new(x); end
  def yaxis; Struct.new(:to_a).new(y); end
  def zaxis; Struct.new(:to_a).new(z); end
end
IDENTITY = Axes.new([1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0])
ROT90 = Axes.new([0.0, 1.0, 0.0], [-1.0, 0.0, 0.0], [0.0, 0.0, 1.0]) # xoay 90° quanh Z: +y cục bộ thành -x thế giới
def shoot_front(settings, dir, transform)
  model, items = world
  items[0].definition = FrontDef.new(dir)
  result = C.shoot(model, {entity: items[0], path: [items[0]], transform: transform}, D.merge(settings))
  [model.active_view, result]
end
def eye_dir(view)
  d = view.states.last[:eye].zip([10.0, 20.0, 30.0]).map { |e, c| e - c }
  l = Math.sqrt(d.sum { |v| v * v }); d.map { |v| v / l }
end
def unit(*v); l = Math.sqrt(v.sum { |x| x * x }); v.map { |x| x / l }; end
view, result = shoot_front({'image_view' => 'isometric'}, '-y', IDENTITY)
check 'có mặt trước -y (trùng trục thế giới): Iso ra đúng hướng cũ (1, -1, 0.8), không ghi chú', near?(eye_dir(view), unit(1, -1, 0.8)) && !result.key?(:note)
view, result = shoot_front({'image_view' => 'isometric'}, '+y', IDENTITY)
check 'mặt trước +y: Iso từ phía +y, bên phải của người đứng trước mặt (-1, 1, 0.8)', near?(eye_dir(view), unit(-1, 1, 0.8))
view, _ = shoot_front({'image_view' => 'isometric'}, '+x', IDENTITY)
check 'mặt trước +x: Iso (1, 1, 0.8)', near?(eye_dir(view), unit(1, 1, 0.8))
view, _ = shoot_front({'image_view' => 'isometric'}, '+y', ROT90)
check 'món xoay 90° quanh Z, mặt trước +y cục bộ = -x thế giới: Iso (-1, -1, 0.8)', near?(eye_dir(view), unit(-1, -1, 0.8))
view, _ = shoot_front({'image_view' => 'front'}, '+y', ROT90)
check 'Chính diện theo mặt trước: camera nhìn thẳng vào mặt trước (phía -x thế giới), cùng độ cao với tâm', near?(eye_dir(view), unit(-1, 0, 0)) && (view.states.last[:eye][2] - 30.0).abs < 1e-6
view, _ = shoot_front({'image_view' => 'front'}, '-x', IDENTITY)
check 'Chính diện, mặt trước -x: camera ở phía -x', near?(eye_dir(view), unit(-1, 0, 0))
view, result = shoot_front({'image_view' => 'isometric'}, nil, IDENTITY)
check 'chưa có mặt trước: chụp theo trục thế giới (1, -1, 0.8) và ghi chú để người dùng biết', near?(eye_dir(view), unit(1, -1, 0.8)) && result[:note] == 'món chưa có mặt trước nên chụp theo trục thế giới'
view, result = shoot_front({'image_view' => 'current'}, '+y', IDENTITY)
check 'Khung nhìn hiện tại: không đặt camera, không ghi chú dù có hay không có mặt trước', view.states.last[:eye] == [0.0, 0.0, 100.0] && !result.key?(:note)
check 'Front.camera_direction: góc nhìn lạ bị từ chối', raises?('góc nhìn') { VGD::BIM::Front.camera_direction('top', [0.0, -1.0]) }
