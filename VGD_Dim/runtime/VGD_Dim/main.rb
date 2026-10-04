# encoding: UTF-8
require 'sketchup.rb'
require 'json'
require_relative 'defaults'
require_relative 'engine'
require_relative 'native_style'
module VGD
  module Dim
    extend self
    def show_error(message)
      if @dialog
        @dialog.execute_script("VGDForm.error(#{JSON.generate(message)});")
      else
        Sketchup.status_text = message
      end
    end
    def apply_payload(payload)
      settings = JSON.parse(payload)
      @dialog.execute_script('VGDForm.busy(true);') if @dialog
      NativeStyle.apply(Sketchup.active_model, settings) do |error|
        @dialog.execute_script('VGDForm.busy(false);') if @dialog
        show_error(error.message) if error
      end
    rescue StandardError => error
      @dialog.execute_script("VGDForm.busy(#{NativeStyle.running?});") if @dialog
      show_error(error.message)
      puts "[VGD Dim/Text] #{error.class}: #{error.message}"
    end
    def open_model_info(page)
      raise "Không mở được Model Info → #{page}." unless UI.show_model_info(page)
    rescue StandardError => error
      show_error(error.message)
    end
    def reload_extension
      load File.join(__dir__, 'reload.rb')
    end
    def show_dialog
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        return
      end
      dialog = UI::HtmlDialog.new(dialog_title: 'VGD Dimension & Text Manager',
        preferences_key: 'VGDDimTextManager', scrollable: true, resizable: false,
        width: 560, height: 650, style: UI::HtmlDialog::STYLE_DIALOG)
      @dialog = dialog
      dialog.set_file(File.join(__dir__, 'dialog.html'))
      dialog.add_action_callback('apply') { |_, payload| apply_payload(payload) }
      dialog.add_action_callback('dim_info') { open_model_info('Dimensions') }
      dialog.add_action_callback('text_info') { open_model_info('Text') }
      dialog.add_action_callback('cancel') { dialog.close }
      dialog.set_on_closed do
        @dialog = nil if @dialog.equal?(dialog)
        NativeStyle.cancel
      end
      dialog.show
    end
    unless @command
      @command = UI::Command.new('VGD Dimension & Text Manager') { show_dialog }
      @command.small_icon = @command.large_icon = File.join(__dir__, 'dim.svg')
      UI.menu('Extensions').add_item(@command) unless file_loaded?(__FILE__)
      @toolbar ||= UI::Toolbar.new('VGD Dimension & Text Manager')
      @toolbar.add_item(@command)
      UI.menu('Extensions').add_item('Hiện toolbar VGD Dim/Text') { @toolbar.show }
      UI.menu('Extensions').add_item('Nạp lại VGD Dim/Text') { reload_extension }
      file_loaded(__FILE__)
    end
    @command.tooltip = 'VGD Dimension & Text Manager'
    @command.status_bar_text = 'Áp mẫu Model Info cho Dim/Text đang chọn; màu, endpoint và tag 000 DIM / 000 TEXT.'
  end
end
