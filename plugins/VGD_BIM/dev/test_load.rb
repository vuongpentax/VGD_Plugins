require 'json'
module Sketchup
  class SelectionObserver; end
  class Group; end
  class ComponentInstance; end
  class Face; end
  class Color; def initialize(*a); end; end
  def self.read_default(*a); nil; end
  def self.write_default(*a); true; end
end
module Geom; class BoundingBox; end; class Transformation; end; end
module UI; class HtmlDialog; end; end
MB_YESNO = 4; IDYES = 6
module VGD; module BIM; ROOT = ARGV[0] || File.expand_path('../runtime/vgd_bim_lite', __dir__); def self.log(m); end; module Data; end; end; end
%w[core/locale core/schema core/storage core/data core/tags core/geometry core/scanner core/table core/validator intake/mapping_rules intake/detector intake/raw_scanner intake/mapping intake/converter core/report_exporter ui/bounds_preview ui/dialog].each do |f|
  require File.join(VGD::BIM::ROOT, f)
  puts "loaded #{f}"
end
puts 'dialog methods: ' + %i[table_build table_select table_edit table_option table_preset table_clear show_outline release_preview cleanup_table_view].map { |m| VGD::BIM::UI::Dialog.method_defined?(m, false) ? 'ok' : "MISSING #{m}" }.join(' ')
puts 'preview tool: ' + (VGD::BIM::UI::BoundsPreview.instance_method(:finish) ? 'ok' : 'missing')
