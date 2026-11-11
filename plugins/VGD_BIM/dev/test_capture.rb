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
    attr_accessor :eye, :target, :up, :height
    attr_writer :perspective, :fov, :fov_is_height
    attr_reader :parallel_reads
    # SketchUp thật in cảnh báo "fov is only valid for perspective cameras" khi đọc fov của camera song song: đếm số lần đọc để test bắt được
    def initialize(eye, target, up); @eye = eye; @target = target; @up = up; @perspective = true; @fov = 35.0; @fov_is_height = false; @height = 100.0; @parallel_reads = 0; end
    def perspective?; @perspective; end
    def fov; @parallel_reads += 1 unless @perspective; @fov; end
    def fov_is_height?; @parallel_reads += 1 unless @perspective; @fov_is_height; end
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
  attr_reader :camera
  attr_accessor :vpwidth, :vpheight, :zoomed, :writes, :fail_next, :fail_on_call, :states, :reject_transparent, :raise_on_transparent, :attempts, :reject_all_options
  def initialize(model); @model = model; @camera = Sketchup::Camera.new(Geom::Point3d.new(0, 0, 100), Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1)); @writes = []; @zoomed = []; @states = []; @vpwidth = 1000; @vpheight = 500; end
  # SketchUp thật hiểu FOV của camera được gán theo chế độ (ngang / dọc) của khung nhìn, nên camera.fov_is_height? của camera mới lấy theo khung nhìn
  def camera=(new_camera); new_camera.fov_is_height = @camera.fov_is_height? if new_camera.perspective? && @camera.perspective?; @camera = new_camera; end
  def refresh; end
  def zoom(entity); @zoomed << entity; end
  def write_image(options)
    (@attempts ||= []) << options.dup
    raise ArgumentError, 'Invalid option: transparent' if @raise_on_transparent && options[:transparent]
    return false if @reject_transparent && options[:transparent]
    return false if @reject_all_options && options[:antialias]
    return false if @fail_next || (@fail_on_call && @writes.size + 1 == @fail_on_call)
    @writes << options
    @states << {active_path: (@model.active_path || []).map(&:pid), hidden: @model.all.select(&:hidden).map(&:pid), selection: @model.selection.map(&:pid), eye: @camera.eye.to_a, target: @camera.target.to_a, perspective: @camera.perspective?, fov: (@camera.perspective? ? @camera.fov : nil), height: @camera.height, options: @model.rendering_options.instance_variable_get(:@values).dup}
    File.binwrite(options[:filename], PNG_BYTES)
    true
  end
end
ORIGINAL_OPTIONS = {'BackgroundColor' => 'sky', 'DrawGround' => true, 'DrawHorizon' => true, 'RenderMode' => 2, 'DisplayColorByLayer' => true}.freeze
class FakeModel
  attr_reader :all, :selection, :rendering_options, :active_view, :ops, :guid
  attr_accessor :active_path
  def initialize(all); @active_path = []; @all = all; @selection = FakeSelection.new; @rendering_options = FakeOptions.new(ORIGINAL_OPTIONS.dup); @active_view = FakeView.new(self); @ops = []; @guid = 'MODEL-1'; end
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

# ---- FOV đang dùng: ảnh Iso / Chính diện / vị trí nhận đúng FOV của khung nhìn (trước đây camera mới luôn lấy 35 độ mặc định) ----
def shoot_with_camera(settings, kind: :full, side: 'right')
  model, items = world
  yield model.active_view.camera
  result = C.shoot(model, {entity: items[0], path: [items[0]]}, D.merge(settings), iso_side: side, kind: kind)
  [model, model.active_view, result]
end
dist_state = ->(st) { Math.sqrt(st[:eye].zip(st[:target]).sum { |e, t| (e - t)**2 }) }
%w[isometric front].each do |name|
  _, v60, _ = shoot_with_camera({'image_view' => name}) { |c| c.fov = 60.0 }
  _, v20, _ = shoot_with_camera({'image_view' => name}) { |c| c.fov = 20.0 }
  check "ảnh #{name}: dùng đúng FOV đang dùng của khung nhìn (60 độ)", v60.states.all? { |st| st[:perspective] && near?([st[:fov]], [60.0]) }
  check "ảnh #{name}: FOV hẹp hơn thì camera lùi xa hơn (20 độ xa hơn 60 độ)", dist_state.(v20.states.last) > dist_state.(v60.states.last) * 1.5
end
model, v60, _ = shoot_with_camera({}, kind: :location) { |c| c.fov = 60.0 }
_, v20, _ = shoot_with_camera({}, kind: :location) { |c| c.fov = 20.0 }
check 'ảnh vị trí: dùng đúng FOV đang dùng (60 độ), FOV hẹp hơn thì camera lùi xa hơn', v60.states.all? { |st| near?([st[:fov]], [60.0]) } && dist_state.(v20.states.last) > dist_state.(v60.states.last) * 1.5
check 'sau khi chụp: FOV của khung nhìn được trả lại như cũ', near?([model.active_view.camera.fov], [60.0])
# FOV theo chiều cao (fov_is_height? = true, như khung nhìn thật của người dùng): SketchUp hiểu giá trị FOV theo chế độ của khung nhìn nên KHÔNG được đổi sang góc ngang,
# nếu không 60 độ thành 82,32 độ sau mỗi lần chụp (lỗi beta.53). Chụp nhiều món liên tiếp phải giữ nguyên FOV.
model, items = world
model.active_view.camera.fov = 60.0
model.active_view.camera.fov_is_height = true
3.times do |i|
  C.shoot(model, {entity: items[i % 3], path: [items[i % 3]]}, D.merge('image_view' => 'isometric'))
  check "FOV theo chiều cao: sau lần chụp thứ #{i + 1} khung nhìn vẫn đúng 60 độ (không tăng)", near?([model.active_view.camera.fov], [60.0])
end
check 'FOV theo chiều cao: lúc chụp camera dùng đúng giá trị FOV của khung nhìn (60), không đổi sang góc ngang', model.active_view.states.all? { |st| near?([st[:fov]], [60.0]) }
model, view, _ = shoot_with_camera({}, kind: :location) { |c| c.fov = 60.0; c.fov_is_height = true }
check 'FOV theo chiều cao (ảnh vị trí): giữ nguyên 60 độ lúc chụp và sau khi chụp', view.states.all? { |st| near?([st[:fov]], [60.0]) } && near?([model.active_view.camera.fov], [60.0])
[{'image_view' => 'isometric'}, {'image_view' => 'front'}].each do |settings|
  model, view, _ = shoot_with_camera(settings) { |c| c.perspective = false; c.height = 250.0 }
  check "camera song song (#{settings['image_view']}): vẫn song song (độ cao khung do khung hình quyết định), không đọc FOV (SketchUp báo cảnh báo)", view.states.all? { |st| !st[:perspective] && st[:height] != 250.0 } && model.active_view.camera.parallel_reads == 0
end
model, view, _ = shoot_with_camera({}, kind: :location) { |c| c.perspective = false; c.height = 250.0 }
check 'camera song song (ảnh vị trí): vẫn song song, không đọc FOV', view.states.all? { |st| !st[:perspective] } && model.active_view.camera.parallel_reads == 0
model, view, _ = shoot_with_camera({'image_view' => 'current'}) { |c| c.fov = 60.0 }
check 'Khung nhìn hiện tại: không đụng camera nên FOV giữ nguyên', view.states.all? { |st| near?([st[:fov]], [60.0]) }

# ---- Xem trước góc chụp (preview): cùng camera như chụp thật, ảnh nhỏ, không lưu gì ----
def shoot_preview(settings = {}, kind: :full, item: 0)
  model, items = world
  model.instance_variable_set(:@guid, "PREVIEW-#{rand(10**9)}") # thư mục ảnh riêng: không lẫn với ảnh do các phép thử khác để lại
  result = C.shoot(model, {entity: items[item], path: [items[item]]}, D.merge(settings), kind: kind, preview: 360)
  [model, items, model.active_view, result]
end
pmodel, _, pview, presult = shoot_preview({'image_view' => 'isometric', 'image_width' => 800, 'image_height' => 400})
_, _, rview, _ = shoot('image_view' => 'isometric', 'image_width' => 800, 'image_height' => 400)
check 'xem trước: trả về nội dung PNG, chụp ảnh nhỏ đúng tỉ lệ ảnh thật (800 x 400 thành 360 x 180)', presult[:png] == PNG_BYTES && pview.writes[0].values_at(:width, :height) == [360, 180]
check 'xem trước: không lưu ảnh nào (không có file ảnh, không file tạm, không file xem trước còn lại)', !File.exist?(I.path(pmodel, 11)) && Dir[File.join(I.dir(pmodel), '*')].empty? && Dir[File.join(I.dir(pmodel), '.preview_*')].empty?
check 'xem trước: camera đặt y như chụp thật (cùng hướng, cùng điểm nhìn, cùng khoảng cách)', pview.states.last[:eye] == rview.states.last[:eye] && pview.states.last[:target] == rview.states.last[:target]
check 'xem trước: cô lập như chụp thật rồi hủy, trả camera và lựa chọn như cũ', pview.states.all? { |st| st[:hidden].sort == [12, 13] } && pmodel.ops == [:start, :abort] && pview.camera.eye.to_a == [0.0, 0.0, 100.0] && pmodel.selection.map(&:pid) == [11, 12]
check 'xem trước: không có mốc thời gian của ảnh (không phải ảnh được lưu)', !presult.key?(:stamp) && presult[:pid] == 11 && presult[:kind] == :full
_, _, v, r = shoot_preview({'image_width' => 200, 'image_height' => 200})
check 'xem trước: ảnh gốc nhỏ hơn 360 thì không phóng to (giữ 200 x 200)', v.writes[0].values_at(:width, :height) == [200, 200]
_, _, v, r = shoot_preview({'loc_view' => 'front', 'loc_yaw' => 90, 'loc_width' => 1000, 'loc_height' => 500}, kind: :location)
check 'xem trước ảnh vị trí: theo thiết lập riêng (góc nhìn, góc lệch, tỉ lệ ảnh vị trí), không lưu file _loc', v.writes[0].values_at(:width, :height) == [360, 180] && near?(eye_dir(v), unit(1, 0, 0)) && r[:png] == PNG_BYTES && Dir[File.join(I.dir(v.instance_variable_get(:@model)), '*')].empty?
_, _, v, r = shoot_preview({'image_view' => 'current'})
check 'xem trước Khung nhìn hiện tại: không đặt camera, vẫn ra ảnh nhỏ', v.states.all? { |st| st[:eye] == [0.0, 0.0, 100.0] } && r[:png] == PNG_BYTES
fmodel, fitems = world
fmodel.instance_variable_set(:@guid, "PREVIEW-#{rand(10**9)}")
fmodel.active_view.fail_next = true
failed = raises? { C.shoot(fmodel, {entity: fitems[0], path: [fitems[0]]}, D, preview: 360) }
check 'xem trước lỗi: báo lỗi, hủy thao tác, trả camera, dọn file xem trước', failed && fmodel.ops == [:start, :abort] && fmodel.active_view.camera.eye.to_a == [0.0, 0.0, 100.0] && Dir[File.join(I.dir(fmodel), '*')].empty? && Dir[File.join(I.dir(fmodel), '.preview_*')].empty?

# ---- Ảnh vị trí (kind: :location): camera y như Iso nhưng không đổi gì trong model (không cô lập, không ẩn, không mở ngữ cảnh), nhìn vùng rộng gấp nhiều lần món, lưu file _loc ----
def shoot_location(settings = {}, side = 'right', user_path = [])
  model, items = world
  model.active_path = user_path.map { |i| items[i] }
  result = C.shoot(model, {entity: items[0], path: [items[0]]}, D.merge(settings), iso_side: side, kind: :location)
  [model, items, model.active_view, result]
end
model, items, view, result = shoot_location('image_view' => 'front') # góc nhìn của preset (Chính diện) không ảnh hưởng ảnh vị trí
check 'ảnh vị trí: không ẩn gì cả (khác ảnh Iso cô lập), không còn đối tượng chọn lúc chụp', view.states.all? { |s| s[:hidden].empty? && s[:selection].empty? }
check 'ảnh vị trí: không đổi ngữ cảnh đang mở của người dùng (về gốc model) lúc chụp', view.states.all? { |s| s[:active_path].empty? }
check 'ảnh vị trí: không mở thao tác nào trong model (không đổi gì, không có bước undo)', model.ops.empty?
check 'ảnh vị trí: sau khi chụp camera và lựa chọn như cũ', model.active_path.to_a.empty? && view.camera.eye.to_a == [0.0, 0.0, 100.0] && model.selection.map(&:pid) == [11, 12]
check 'ảnh vị trí: lưu vào file _loc, không còn file tạm', File.binread(I.path(model, 11, :location)) == PNG_BYTES && File.basename(I.path(model, 11, :location)) == '11_loc.png' && Dir[File.join(I.dir(model), '*.tmp.png')].empty?
check 'ảnh vị trí: kết quả ghi loại ảnh và mốc thời gian', result[:kind] == :location && result[:pid] == 11 && result[:stamp] > 0
check 'ảnh vị trí: nhìn theo góc Iso (1, -1, 0.8) nhìn vào tâm món', view.states.all? { |s| s[:target] == [10.0, 20.0, 30.0] && near?(s[:eye].zip([10.0, 20.0, 30.0]).map { |e, c| e - c }.then { |d| l = Math.sqrt(d.sum { |v| v * v }); d.map { |v| v / l } }, [1, -1, 0.8].then { |d| l = Math.sqrt(d.sum { |v| v * v }); d.map { |v| v / l } }) }
dist_of = ->(v) { s = v.states.last; Math.sqrt(s[:eye].zip(s[:target]).sum { |e, t| (e - t)**2 }) }
_, _, iso_view, _ = shoot('image_view' => 'isometric')
_, _, scale4, _ = shoot_location
_, _, scale2, _ = shoot_location('image_location_scale' => 2)
_, _, scale10, _ = shoot_location('image_location_scale' => 10)
_, _, scale1, _ = shoot_location('image_location_scale' => 1)
check 'ảnh vị trí: vùng nhìn gấp 1 lần thì camera đặt đúng như ảnh Iso của món', (dist_of.(scale1) - dist_of.(iso_view)).abs < 1e-6
iso_state, loc_state = iso_view.states.last, scale4.states.last
dir_of = ->(st) { d = st[:eye].zip(st[:target]).map { |e, t| e - t }; l = Math.sqrt(d.sum { |v| v * v }); d.map { |v| v / l } }
check 'ảnh vị trí: cùng hướng nhìn và cùng điểm nhìn với ảnh Iso của món (chỉ khác khoảng cách)', near?(dir_of.(iso_state), dir_of.(loc_state)) && iso_state[:target] == loc_state[:target]
check 'ảnh vị trí: nhìn vùng rộng gấp 4 lần (mặc định) nên camera lùi xa hơn ảnh Iso của món khoảng 4 lần', dist_of.(scale4) > dist_of.(iso_view) * 3.0 && dist_of.(scale4) < dist_of.(iso_view) * 4.2
check 'ảnh vị trí: hệ số vùng nhìn của preset được dùng (2 gần hơn 4, 10 xa hơn 4)', dist_of.(scale2) < dist_of.(scale4) && dist_of.(scale4) < dist_of.(scale10)
# ---- Thiết lập riêng của ảnh vị trí (cỡ, góc nhìn, kiểu, nền, lề, góc lệch / góc cao); ảnh chính không bị ảnh hưởng ----
_, _, v, _ = shoot_location('loc_width' => 1024, 'loc_height' => 640, 'image_width' => 300, 'image_height' => 300)
check 'ảnh vị trí: cỡ ảnh theo thiết lập riêng (1024 x 640), không theo ảnh chính', v.writes[0].values_at(:width, :height) == [1024, 640]
_, _, v, _ = shoot('image_view' => 'isometric', 'image_width' => 300, 'image_height' => 300, 'loc_width' => 1024, 'loc_height' => 640)
check 'ảnh chính: vẫn theo cỡ của ảnh chính (300 x 300), không theo thiết lập ảnh vị trí', v.writes[0].values_at(:width, :height) == [300, 300]
_, _, v, _ = shoot_location('image_style' => 'color', 'loc_style' => 'current')
check 'ảnh vị trí: kiểu hiển thị riêng (Kiểu hiện tại thì không đổi kiểu dù ảnh chính là Màu)', v.states.all? { |st| st[:options]['RenderMode'] == 2 && st[:options]['DisplayColorByLayer'] == true }
_, _, v, _ = shoot_location('image_style' => 'current', 'loc_style' => 'color')
check 'ảnh vị trí: kiểu Màu riêng áp dụng dù ảnh chính để Kiểu hiện tại', v.states.all? { |st| st[:options]['RenderMode'] == 3 && st[:options]['DisplayColorByLayer'] == false }
_, _, v, _ = shoot_location('image_background' => 'white', 'loc_background' => 'transparent')
check 'ảnh vị trí: nền riêng (trong suốt, không đổi nền model) dù ảnh chính là nền trắng', v.writes[0][:transparent] == true && v.states.all? { |st| st[:options]['DrawGround'] == true }
_, _, v, _ = shoot_location('image_background' => 'transparent', 'loc_background' => 'white')
check 'ảnh vị trí: nền trắng riêng áp dụng dù ảnh chính là nền trong suốt', v.writes[0][:transparent] == false && v.states.all? { |st| st[:options]['DrawGround'] == false }
_, _, m0, _ = shoot_location('loc_margin' => 0)
_, _, m60, _ = shoot_location('loc_margin' => 60)
_, _, main60, _ = shoot_location('image_margin' => 60)
check 'ảnh vị trí: lề riêng (60% thì camera xa hơn 0%), không theo lề của ảnh chính', dist_of.(m60) > dist_of.(m0) * 1.4 && (dist_of.(main60) - dist_of.(scale4)).abs < 1e-6
_, _, v, result = shoot_location('loc_view' => 'front')
check 'ảnh vị trí chọn Chính diện: nhìn thẳng từ mặt trước (chưa có mặt trước thì theo trục thế giới -Y, có ghi chú)', near?(eye_dir(v), unit(0, -1, 0)) && result[:note] == 'món chưa có mặt trước nên chụp theo trục thế giới'
_, _, v, _ = shoot_location('loc_view' => 'front', 'loc_yaw' => 90)
check 'ảnh vị trí Chính diện lệch phải 90 độ: camera sang bên phải (+X)', near?(eye_dir(v), unit(1, 0, 0))
_, _, v, _ = shoot_location('loc_view' => 'front', 'loc_yaw' => -30)
check 'ảnh vị trí Chính diện lệch trái 30 độ: camera sang bên trái (-X), vẫn ngang', near?(eye_dir(v), [-Math.sin(Math::PI / 6), -Math.cos(Math::PI / 6), 0.0])
_, _, v, _ = shoot_location('loc_view' => 'front', 'loc_yaw' => 20, 'loc_pitch' => 30)
check 'ảnh vị trí Chính diện lệch phải 20 độ và nâng 30 độ', near?(eye_dir(v), [Math.sin(Math::PI * 20 / 180) * Math.cos(Math::PI / 6), -Math.cos(Math::PI * 20 / 180) * Math.cos(Math::PI / 6), 0.5])
_, _, v, _ = shoot_location('loc_view' => 'front', 'image_yaw' => 90, 'image_pitch' => 40)
check 'góc lệch của ảnh chính không ảnh hưởng ảnh vị trí', near?(eye_dir(v), unit(0, -1, 0))
_, _, v, _ = shoot_location('loc_view' => 'isometric', 'loc_yaw' => 40, 'loc_pitch' => 20)
check 'ảnh vị trí chọn Iso: góc lệch / góc cao không áp dụng, vẫn đúng hướng Iso', near?(eye_dir(v), unit(1, -1, 0.8))
_, _, v, result = shoot_location('loc_view' => 'current')
check 'ảnh vị trí chọn Khung nhìn hiện tại: không đặt camera, không ghi chú, vẫn chụp đúng cỡ riêng', v.states.all? { |st| st[:eye] == [0.0, 0.0, 100.0] } && !result.key?(:note) && v.writes[0].values_at(:width, :height) == [512, 512]
_, _, v, _ = shoot('image_view' => 'front', 'image_yaw' => 90)
check 'ảnh chính Chính diện lệch phải 90 độ: camera sang bên phải (+X)', near?(eye_dir(v), unit(1, 0, 0))
_, _, v, _ = shoot('image_view' => 'front', 'image_yaw' => -20, 'image_pitch' => 25)
check 'ảnh chính Chính diện lệch trái 20 độ và nâng 25 độ', near?(eye_dir(v), [-Math.sin(Math::PI * 20 / 180) * Math.cos(Math::PI * 25 / 180), -Math.cos(Math::PI * 20 / 180) * Math.cos(Math::PI * 25 / 180), Math.sin(Math::PI * 25 / 180)])
_, _, v, _ = shoot('image_view' => 'isometric', 'image_yaw' => 40, 'image_pitch' => 20)
check 'ảnh chính Iso: góc lệch / góc cao không áp dụng', near?(eye_dir(v), unit(1, -1, 0.8))
_, _, v, _ = shoot('image_view' => 'front', 'loc_yaw' => 60, 'loc_pitch' => 30)
check 'ảnh chính: góc lệch của ảnh vị trí không ảnh hưởng', near?(eye_dir(v), unit(0, -1, 0))
_, _, v, _ = shoot_location({'loc_view' => 'front', 'loc_yaw' => 90}, 'left')
check 'nút trái / phải (Iso) không đổi góc lệch của Chính diện: bên Iso chỉ dùng cho Iso', near?(eye_dir(v), unit(1, 0, 0))

_, _, left_view, _ = shoot_location({}, 'left')
check 'ảnh vị trí: nút trái / phải đối xứng nhau qua mặt phẳng nhìn thẳng (x đảo dấu quanh tâm)', near?([left_view.states.last[:eye][0] - 10.0], [-(scale4.states.last[:eye][0] - 10.0)]) && near?([left_view.states.last[:eye][1]], [scale4.states.last[:eye][1]])
model, items, view, _ = shoot_location({}, 'right', [2])
check 'người dùng đang mở sửa một group khác: ngữ cảnh đó giữ nguyên suốt lúc chụp và sau khi chụp', model.active_path.map(&:pid) == [13] && view.states.all? { |s| s[:active_path] == [13] }
model, items = world
model.active_view.fail_next = true
failed = raises? { C.shoot(model, {entity: items[0], path: [items[0]]}, D, kind: :location) }
check 'ảnh vị trí chụp lỗi: model không bị đổi, camera như cũ, dọn file tạm', failed && model.active_path.to_a.empty? && model.ops.empty? && model.active_view.camera.eye.to_a == [0.0, 0.0, 100.0] && Dir[File.join(I.dir(model), '*.tmp.png')].empty?
check 'loại ảnh lạ bị từ chối', raises?('loại ảnh') { C.shoot(world[0], {entity: world[1][0], path: [world[1][0]]}, D, kind: :zzz) }
model.active_view.fail_next = false
check 'ảnh vị trí và ảnh món là hai file riêng', (C.shoot(model, {entity: items[0], path: [items[0]]}, D); C.shoot(model, {entity: items[0], path: [items[0]]}, D, kind: :location); File.exist?(I.path(model, 11)) && File.exist?(I.path(model, 11, :location)))
