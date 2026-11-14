# frozen_string_literal: true

require 'sketchup.rb'
require 'json'
require 'fileutils'
require 'digest'
require 'time'

# Menu Extensions > VGD dùng chung: mọi plugin VGD lấy cùng một menu (SketchUp không gộp các menu trùng tên).
module VGD
  def self.menu
    @extensions_menu ||= ::UI.menu('Extensions').add_submenu('VGD')
  end unless respond_to?(:menu)
end

module VGD
  module Pack
    PLUGIN_VERSION = '0.1.6'.freeze unless const_defined?(:PLUGIN_VERSION)
    ROOT = File.dirname(__FILE__.dup.force_encoding(Encoding::UTF_8)).freeze unless const_defined?(:ROOT)

    # Danh sách file nạp, dùng chung cho lúc khởi động và lúc "Tải lại code".
    CODE_FILES = %w[compatibility asset adapters/sketchup_texture adapters/sketchup_pbr scanner
                    research/enscape_inspector ui/dialog].freeze unless const_defined?(:CODE_FILES)
    CODE_FILES.each { |name| require File.join(ROOT, name) }

    # Nạp lại mã mà không cần mở lại SketchUp. Kiểm tra cú pháp cả bộ file trước: có lỗi thì giữ nguyên bản đang chạy.
    def self.reload
      files = CODE_FILES.map { |name| File.join(ROOT, "#{name}.rb") } + [File.join(ROOT, 'vgd_pack.rb')]
      files.each { |file| RubyVM::InstructionSequence.compile_file(file) }
      reopen = UI.dialog_open?
      UI.close_dialog if reopen
      old_version = PLUGIN_VERSION
      old_files = CODE_FILES
      verbose = $VERBOSE
      $VERBOSE = nil # tránh cảnh báo "hằng số đã khai báo" khi nạp lại
      begin
        remove_const(:PLUGIN_VERSION)
        remove_const(:CODE_FILES)
        files.each { |file| load file }
      rescue ScriptError, StandardError
        const_set(:PLUGIN_VERSION, old_version) unless const_defined?(:PLUGIN_VERSION, false)
        const_set(:CODE_FILES, old_files) unless const_defined?(:CODE_FILES, false)
        raise
      ensure
        $VERBOSE = verbose
      end
      UI.show if reopen
      ::UI.messagebox("Đã tải lại VGD Package #{PLUGIN_VERSION}.")
      true
    rescue ScriptError, StandardError => error
      ::UI.messagebox("Tải lại thất bại:\n#{error.class}: #{error.message}\n\nBản đang chạy được giữ nguyên.")
      false
    end

    unless file_loaded?(__FILE__)
      unless Compatibility.supported?
        ::UI.messagebox('VGD Package cần SketchUp 2022 trở lên.')
      else
        menu = ::VGD.menu.add_submenu('VGD Package')
        menu.add_item('Mở VGD Package') { UI.show }
        menu.add_item('Tải lại code') { reload }
      end
      file_loaded(__FILE__)
    end
  end
end
