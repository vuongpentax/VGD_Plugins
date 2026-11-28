# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require_relative 'version'
require_relative 'tree'
require_relative 'model_io'
require_relative 'dialog'

# Menu Extensions > VGD dùng chung: mọi plugin VGD lấy cùng một menu (SketchUp không gộp các menu trùng tên).
module VGD
  def self.menu
    @extensions_menu ||= ::UI.menu('Extensions').add_submenu('VGD')
  end unless respond_to?(:menu)
end

module VGD
  module Diagram
    extend self

    def show_dialog
      Dialog.show
    end

    # reload.rb kiểm tra cú pháp cả bộ file trước khi nạp nên lỗi cú pháp không làm hỏng bản đang chạy.
    def reload_extension
      if Dialog.busy?
        UI.messagebox("Đang ghi thứ tự lắp vào model.\nHãy chờ xong rồi tải lại code.")
        return false
      end
      load File.join(__dir__.dup.force_encoding(Encoding::UTF_8), 'reload.rb')
      UI.messagebox("Đã tải lại VGD Diagram #{VERSION}.")
      true
    rescue ScriptError, StandardError => error
      tail = error.is_a?(SyntaxError) ? 'Bản đang chạy được giữ nguyên.' : 'Hãy mở lại SketchUp nếu giao diện báo lỗi.'
      UI.messagebox("Tải lại thất bại:\n#{error.class}: #{error.message}\n\n#{tail}")
      false
    end

    unless @registered
      icon = File.join(__dir__.dup.force_encoding(Encoding::UTF_8), 'diagram.svg')
      @command = UI::Command.new('VGD Diagram') { show_dialog }
      @command.small_icon = @command.large_icon = icon
      @command.tooltip = 'VGD Diagram'
      @command.status_bar_text = 'Sơ đồ cây lắp ráp: cấu kiện, số lượng và thứ tự lắp.'
      menu = ::VGD.menu.add_submenu('VGD Diagram')
      menu.add_item(@command)
      menu.add_item('Tải lại code') { reload_extension }
      @toolbar = UI::Toolbar.new('VGD DGM')
      @toolbar.add_item(@command)
      # Lần đầu cài thì hiện thanh công cụ; các lần sau giữ trạng thái người dùng đã chọn.
      @toolbar.get_last_state == TB_NEVER_SHOWN ? @toolbar.show : @toolbar.restore
      @registered = true
    end
  end
end
