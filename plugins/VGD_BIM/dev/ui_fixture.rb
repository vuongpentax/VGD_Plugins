# In ra JSON dữ liệu thật do Ruby gửi cho giao diện (cột, preset, nhãn, từ điển) để test giao diện dùng đúng dữ liệu thật.
# Chạy: ruby dev/ui_fixture.rb
require 'json'
require 'tmpdir'
ENV['VGD_BIM_DATA_DIR'] ||= Dir.mktmpdir('vgd_bim_fixture')
module Sketchup; class Group; end; class ComponentInstance; end; class Face; end; end
module VGD; module BIM; def self.log(_); end; module Data; end; module Scanner; end; module Geometry; end; end; end
ROOT = File.expand_path('../runtime/vgd_bim', __dir__)
%w[core/locale core/schema core/tags core/table].each { |f| require File.join(ROOT, f) }
B = VGD::BIM
puts JSON.generate(
  fields: B::Schema::FIELDS, categories: B::Schema::CATEGORIES, units: B::Schema::UNITS, methods: B::Schema::METHODS,
  columns: B::Table::COLUMNS, presets: B::Table.presets, statuses: B::Table::STATUS_LABELS,
  groups: B::Tags::GROUPS + [B::Table::UNTAGGED_GROUP],
  vi: B::Locale.dictionary, en: B::Locale.ui_dictionary('en'), vi_en: B::Locale.vi_en_names
)
