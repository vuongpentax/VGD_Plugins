# Kiểm tra Table.build: chế độ mặc định (chỉ đối tượng đang chọn) và chế độ chọn sâu.
ROOT = ARGV[0] || File.expand_path('../runtime/vgd_bim_lite', __dir__)
$fails = 0
def ok(name, cond); puts(cond ? "PASS  #{name}" : "FAIL  #{name}"); $fails += 1 unless cond; end

module Sketchup
  class Group; attr_accessor :name, :children, :transformation, :layer, :locked; def initialize(n, kids = []); @name = n; @children = kids; @transformation = Tr.new; @locked = false; end; def valid?; true; end; def locked?; @locked; end; def volume; 1.0; end; def entityID; object_id; end; def material; nil; end; def entities; @children; end; end
  class ComponentInstance < Group; end
  class Face; end
  def self.read_default(*); nil; end
  def self.write_default(*); true; end
end
class Tr
  def *(_o); self; end
  def xaxis; Vec.new; end; def yaxis; Vec.new; end; def zaxis; Vec.new; end
  class Vec; def length; 1.0; end; end
end
module VGD; module BIM
  def self.log(m); end
  module Data
    def self.supported?(e); e.is_a?(Sketchup::Group); end
    def self.read(_e); {status: '', description: ''}; end
  end
  module Scanner
    # Mô phỏng Scanner.walk đệ quy: gọi block cho mọi group lồng bên trong.
    def self.walk(entities, transform, path, ancestors, material, locked, faces: true, &block)
      entities.each do |e|
        cur = path + [e]
        block.call(entity: e, transform: transform, path: cur, material: nil, locked: false)
        walk(e.entities, transform, cur, ancestors, material, locked, faces: faces, &block)
      end
    end
  end
  module Geometry
    def self.dimensions(_e, _t); {width: 1000.0, depth: 500.0, height: 2000.0}; end
    def self.definition(e); Defn.new(e); end
    def self.face_area(*); 0.0; end
    class Defn; def initialize(e); @e = e; end; def name; @e.name; end; def entities; @e.entities; end; def bounds; Box.new; end; def count_instances; 1; end; end
    class Box; def empty?; true; end; end
  end
  module Tags
    def self.load; []; end
    def self.key(n); n.to_s.downcase; end
    GROUPS = ['Phần thô'].freeze
  end
end; end
require File.join(ROOT, 'core/table')

class Model; attr_accessor :active_path; def edit_transform; Tr.new; end; end
inner = Sketchup::Group.new('Con')
top = Sketchup::Group.new('Cha', [inner])
other = Sketchup::Group.new('Khác')
m = Model.new; m.active_path = []

shallow = VGD::BIM::Table.build(m, [top, other], false)[:rows]
ok('mặc định: đọc đúng 2 đối tượng được chọn', shallow.size == 2)
ok('mặc định: không đọc đối tượng con lồng bên trong', shallow.none? { |r| r[:name] == 'Con' })
ok('mặc định: dòng có kích thước đúng (mm)', shallow[0][:lenX] == 1000.0 && shallow[0][:lenZ] == 2000.0)
ok('mặc định: không có cha trong danh sách (parents rỗng)', shallow.all? { |r| r[:parents].empty? })

deep = VGD::BIM::Table.build(m, [top, other], true)[:rows]
ok('chọn sâu: đọc cả 3 đối tượng (kể cả con lồng)', deep.size == 3)
ok('chọn sâu: con lồng có cha trong bảng', deep.find { |r| r[:name] == 'Con' }[:parents] == [deep.find { |r| r[:name] == 'Cha' }[:index]])

puts $fails.zero? ? 'Done: tất cả PASS' : "Done: #{$fails} FAIL"
