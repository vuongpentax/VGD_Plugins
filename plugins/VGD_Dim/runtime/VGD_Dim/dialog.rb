# encoding: UTF-8
module VGD
  module Dim
    module Dialog
      extend self
      def visible?; @dlg && @dlg.visible?; end
      def close
        @dlg.close if @dlg
        @dlg=nil
      end
      def callback(name,&block)
        @dlg.add_action_callback(name) do |context,payload|
          begin
            block.call(payload)
          rescue StandardError => error
            send_js('onBusy',false)
            send_js('onError',{'message'=>error.message})
          end
        end
      end
      def show
        if visible?
          @dlg.bring_to_front
          return
        end
        @dlg=UI::HtmlDialog.new(dialog_title:'VGD Dim',preferences_key:'VGDDim',
          width:760,height:760,min_width:360,min_height:520,resizable:true,style:UI::HtmlDialog::STYLE_DIALOG)
        @dlg.set_file(File.join(__dir__,'dialog.html'))
        callback('ready') { push_state }
        callback('scan') { |json| send_js('onScan',Core.summary(Core.scan(Sketchup.active_model,JSON.parse(json).fetch('opts')))) }
        callback('run') do |json|
          p=JSON.parse(json)
          send_js('onResult',Core.run(p.fetch('kinds'),p.fetch('settings'),p.fetch('opts')))
        end
        callback('rebuild') { |json| send_js('onRebuild',Core.rebuild_dims(JSON.parse(json).fetch('opts'))) }
        callback('set_boundary') do
          Regions.begin_pick('boundary')
          send_js('onToolStart',{'message'=>'Chọn hai góc đối diện của Boundary trong model.'})
        end
        callback('set_detail') do |json|
          Regions.begin_pick('detail',JSON.parse(json).fetch('name'))
          send_js('onToolStart',{'message'=>'Chọn hai góc đối diện của Detail Region trong Boundary.'})
        end
        callback('set_region') do |json|
          p=JSON.parse(json)
          send_js('onRegions',Regions.set_active(Sketchup.active_model,p.fetch('id')))
        end
        callback('delete_region') do |id|
          send_js('onRegions',Regions.delete_detail(Sketchup.active_model,id))
        end
        callback('manual_dim') do |json|
          ManualDim.start(JSON.parse(json).fetch('settings'))
          send_js('onToolStart',{'message'=>'Chọn điểm đầu, điểm cuối, rồi chọn phía đặt Dim.'})
        end
        callback('smart_dim') do |json|
          p=JSON.parse(json)
          result=SmartDim.execute(p.fetch('opts'),p.fetch('settings'))
          send_js('onSmart',result)
        end
        callback('units_apply') do |json|
          send_js('onUnits',Core.apply_units_model(JSON.parse(json).fetch('settings')))
        end
        callback('save_preset') do |json|
          p=JSON.parse(json)
          raise 'Tên preset trống hoặc trùng preset hệ thống.' unless Presets.save(p.fetch('name'),p.fetch('settings'))
          send_js('onToast',{'message'=>"Đã lưu preset #{p['name']}."})
          push_state(p['name'])
        end
        callback('delete_preset') do |name|
          raise 'Không xóa được preset này.' unless Presets.delete(name)
          push_state
        end
        callback('set_auto') do |json|
          p=JSON.parse(json)
          AutoStyle.save(p.fetch('enabled'),p.fetch('settings'))
          send_js('onToast',{'message'=>p['enabled'] ? 'Auto-Style đang bật.' : 'Auto-Style đã tắt.'})
        end
        callback('anim_set') do |json|
          send_js('onAnim',Animation.write(Sketchup.active_model,JSON.parse(json)))
          send_js('onToast',{'message'=>'Đã cập nhật Animation. Thiết lập này không nằm trong Undo.'})
        end
        callback('dim_info') { VGD::Dim.open_model_info('Dimensions') }
        callback('text_info') { VGD::Dim.open_model_info('Text') }
        callback('native_apply') do
          send_js('onBusy',true)
          NativeStyle.apply(Sketchup.active_model,{},apply_setters:false) do |error|
            send_js('onBusy',false)
            error ? send_js('onError',{'message'=>error.message}) : send_js('onToast',{'message'=>''})
          end
        end
        @dlg.set_on_closed { @dlg=nil; NativeStyle.cancel }
        @dlg.show
      end
      def push_state(select=nil)
        send_js('onState',{'version'=>VGD::Dim::VERSION,'presets'=>Presets.all,'builtin'=>Presets::BUILTIN.keys,'select'=>select,
          'auto'=>AutoStyle.load,'smart'=>SmartDim.saved['opts'],'smart_style'=>SmartDim.saved['settings'],
          'units'=>Core.read_units(Sketchup.active_model),'anim'=>Animation.read(Sketchup.active_model),'regions'=>Regions.public_state(Sketchup.active_model)})
      end
      def send_js(fn,data)
        @dlg.execute_script("VGD.#{fn}(#{JSON.generate(data)})") if @dlg
      end
    end
  end
end
