# frozen_string_literal: true
require 'sketchup.rb'
require 'json'
require_relative 'geometry_engine'
require_relative 'modeling_rules'
require_relative 'modeling'
require_relative 'defaults'
require_relative 'ui_renderer'
require_relative 'draw_tool'
require_relative 'reload'
require_relative 'preset_store'
require_relative 'description_import'
require_relative 'preview_mesh'
require_relative 'library_store'
require_relative 'model_data'
require_relative 'box_conversion'
require_relative 'update_notice'
module VGD_Cabinet
  remove_const(:VERSION) if const_defined?(:VERSION, false)
  VERSION = '4.5.3'
  remove_const(:FRONT_SETTING_KEYS) if const_defined?(:FRONT_SETTING_KEYS, false)
  FRONT_SETTING_KEYS = %w[
    opt_door door_style auto_door_count max_door_w door_count
    door_gap_advanced door_gap door_gap_outer door_gap_between door_gap_left door_gap_right door_gap_top door_gap_bottom door_top_gap
    front_bevel bevel_lip frame_joint frame_division frame_sections frame_bar_width
    metal_frame_width metal_frame_depth glass_thickness metal_finish glass_finish
    pano_stile_width pano_rail_width pano_depth pano_panel_thickness pano_groove_depth pano_clearance pano_panel_count pano_mid_rail shaker_recess
    wood_carved_thickness wood_carved_rail wood_carved_radius wood_carved_recess
    wood_bevel_thickness wood_bevel_flat wood_bevel_width wood_bevel_recess
    wood_glass_frame_thickness wood_glass_rail wood_glass_radius wood_glass_depth wood_glass_inset wood_glass_type
    opt_drawer is_full_drawer drawer_count drawer_columns drawer_comp_pos drawer_hinge_sp drawer_inner_offset drawer_h_inner
    drawer_gap_advanced drawer_gap drawer_gap_outer drawer_gap_between drawer_gap_left drawer_gap_right drawer_gap_top drawer_gap_bottom
    drawer_frame_depth drawer_frame_rail_width drawer_frame_stop_rail drawer_frame_stop_rail_h drawer_frame_stop_rail_drop
    drawer_backing_rail drawer_backing_rail_h drawer_backing_rail_joinery door_stop_rail door_stop_rail_h door_stop_rail_joinery
    drawer_bevel drawer_bevel_lip drawer_ray_space drawer_back_clearance drawer_box_bottom_lift drawer_box_top_clearance
    drawer_bottom_offset drawer_box_t drawer_bottom_t drawer_bottom_mode
  ].freeze
  class CabinetSelectionObserver < Sketchup::SelectionObserver
    def onSelectionBulkChange(_s); VGD_Cabinet.sync_current_selection; end
    def onSelectionAdded(_s,_e); VGD_Cabinet.sync_current_selection; end
    def onSelectionRemoved(_s,_e); VGD_Cabinet.sync_current_selection; end
    def onSelectionCleared(_s); VGD_Cabinet.sync_current_selection; end
  end
  class PlacementTool
    def suspend(view)
      view.invalidate
    end
    def deactivate(view)
      view.invalidate
    end
    def initialize(p, library_name=nil)
      @p=p; @library_name=library_name; @model=Sketchup.active_model; @ip=Sketchup::InputPoint.new
      @entry=library_name ? VGD_Cabinet.library_store.entry(library_name) : nil
      @mesh=@entry ? PreviewMesh.from_data(VGD_Cabinet.library_store.preview(@entry)) : PreviewMesh.new(p)
    end
    def activate; Sketchup.status_text='Click để đặt tủ theo trục của ngữ cảnh hiện tại; Esc để hủy.'; end
    def onMouseMove(_flags,x,y,view); @ip.pick(view,x,y); view.invalidate; end
    def preview_transform
      point=@ip.position.transform(@model.edit_transform.inverse)
      @model.edit_transform*Geom::Transformation.translation(point.to_a)
    end
    def getExtents
      bounds=Geom::BoundingBox.new
      8.times { |i| bounds.add(@mesh.bounds.corner(i).transform(preview_transform)) } if @ip.valid? && !@mesh.bounds.empty?
      bounds
    end
    def draw(view)
      return unless @ip.valid?
      @mesh.draw(view,preview_transform)
      @ip.draw(view)
      view.draw_text([24,24],"VGD · #{@library_name || 'Đặt tủ mới'} · Click để đặt / Esc để hủy",color:Sketchup::Color.new(125,89,58),size:11)
    end
    def onLButtonDown(_flags,x,y,view)
      @ip.pick(view,x,y)
      return unless @ip.valid?
      model=Sketchup.active_model
      point=@ip.position.transform(model.edit_transform.inverse)
      return VGD_Cabinet.report_error(ModelingRules::Invalid.new('Đã đổi file SketchUp. Chọn lại mẫu để đặt.')) unless model.equal?(@model)
      if @entry
        VGD_Cabinet.place_library_cabinet(@entry,@library_name,Geom::Transformation.translation(point.to_a))
      else
        VGD_Cabinet.create_new_cabinet_at(@p,Geom::Transformation.translation(point.to_a))
      end
      model.select_tool(nil)
    end
    def onCancel(_reason,_view); Sketchup.active_model.select_tool(nil); end
  end
  class UpdatePreviewTool
    def suspend(view)
      view.invalidate
    end
    def deactivate(view)
      view.invalidate
    end
    def initialize(target_pid,model_guid,input,mesh)
      @target_pid=target_pid.to_i; @model_guid=model_guid.to_s
      @input=input.dup; @mesh=mesh
    end
    def activate
      Sketchup.status_text='Xem trước hình học dựng lại · Enter áp dụng · Esc hủy. Hình học sửa tay có thể bị thay thế.'
    end
    def target
      model=Sketchup.active_model
      return nil unless model.guid.to_s==@model_guid
      model.find_entity_by_persistent_id(@target_pid)
    rescue
      nil
    end
    def getExtents
      bounds=Geom::BoundingBox.new; inst=target
      if inst && inst.valid? && !@mesh.bounds.empty?
        8.times { |i| bounds.add(@mesh.bounds.corner(i).transform(inst.transformation)) }
      end
      bounds
    end
    def draw(view)
      inst=target
      unless inst && inst.valid?
        view.draw_text([24,24],'Tủ đã thay đổi hoặc file đã đóng · Esc để thoát')
        return
      end
      @mesh.draw(view,inst.transformation)
      view.draw_text([24,24],'VGD · XEM TRƯỚC DỰNG LẠI',color:Sketchup::Color.new(200,169,138),size:12,bold:true)
      view.draw_text([24,46],'Enter: áp dụng  ·  Esc: hủy',color:Sketchup::Color.new(255,255,255),size:10)
      view.draw_text([24,64],'Có thể thay hình học đã chỉnh tay. Lưu mẫu Thư viện trước nếu cần giữ.',color:Sketchup::Color.new(255,205,140),size:10)
    end
    def onKeyDown(key,_repeat,_flags,_view)
      if key==27
        Sketchup.active_model.select_tool(nil)
      elsif key==13
        model=Sketchup.active_model; inst=target
        unless inst && inst.valid?
          VGD_Cabinet.report_error(ModelingRules::Invalid.new('Không tìm thấy tủ để cập nhật; thao tác đã hủy.'))
          model.select_tool(nil); return
        end
        model.selection.clear; model.selection.add(inst)
        @input['__model_guid']=@model_guid
        @input['__target_pid']=@target_pid.to_s
        VGD_Cabinet.update_selected_cabinet(@input)
        model.select_tool(nil)
      end
    end
    def onCancel(_reason,_view); Sketchup.active_model.select_tool(nil); end
  end
  # Batch edits reuse the ordinary VGD generator, but preview every target
  # before a single undoable operation replaces any of their geometry.
  class BatchUpdatePreviewTool
    def suspend(view)
      view.invalidate
    end
    def deactivate(view)
      view.invalidate
    end
    def initialize(records, model_guid)
      @records = records
      @model_guid = model_guid.to_s
    end
    def activate
      Sketchup.status_text = 'VGD · Xem trước cập nhật hàng loạt · Enter áp dụng cả lô · Esc hủy.'
    end
    def getExtents
      bounds = Geom::BoundingBox.new
      @records.each do |record|
        next unless record[:instance].valid?
        8.times { |i| bounds.add(record[:mesh].bounds.corner(i).transform(record[:transform])) }
      end
      bounds
    end
    def draw(view)
      @records.each do |record|
        next unless record[:instance].valid?
        record[:mesh].draw(view, record[:transform])
      end
      view.draw_text([24,24], "VGD · XEM TRƯỚC #{@records.size} TỦ", color: Sketchup::Color.new(200,169,138), size: 12, bold: true)
      view.draw_text([24,46], 'Enter: dựng lại và áp dụng trong một Undo · Esc: hủy', color: Sketchup::Color.new(255,255,255), size: 10)
      view.draw_text([24,64], 'Hình học chỉnh tay trong các tủ được chọn có thể bị thay thế.', color: Sketchup::Color.new(255,205,140), size: 10)
    end
    def onKeyDown(key, _repeat, _flags, _view)
      if key == 27
        Sketchup.active_model.select_tool(nil)
      elsif key == 13
        VGD_Cabinet.apply_batch_front_settings(@records.map { |record| [record[:instance].persistent_id, record[:params]] }, @model_guid)
        Sketchup.active_model.select_tool(nil)
      end
    end
    def onCancel(_reason, _view); Sketchup.active_model.select_tool(nil); end
  end
  class << self
    attr_accessor :dialog
    def is_updating_from_ui?; @busy == true; end
    def dialog_visible?; @dialog && @dialog.visible?; end
    def is_cabinet_entity?(e)
      return false unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      %w[VGD_Cabinet TPlus_Cabinet].any? { |dict| e.get_attribute(dict,'is_cabinet',false) || e.definition.get_attribute(dict,'is_cabinet',false) }
    end
    def find_cabinet_instance
      selection=Sketchup.active_model.selection
      return nil unless selection.length == 1
      e=selection.first
      is_cabinet_entity?(e) ? e : nil
    end
    def get_cabinet_params(e)
      json=%w[VGD_Cabinet TPlus_Cabinet].map { |dict| e.get_attribute(dict,'params_json',nil) || e.definition.get_attribute(dict,'params_json',nil) }.compact.first
      parsed=json ? JSON.parse(json) : nil
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end
    def set_cabinet_params(e,p,cabinet_id=nil)
      cabinet_id ||= ModelData.cabinet_id(e) || SecureRandom.uuid
      e.set_attribute('VGD_Cabinet','is_cabinet',true)
      e.set_attribute('VGD_Cabinet','params_json',JSON.generate(p))
      e.set_attribute('VGD_Cabinet','version',VERSION)
      ModelData.assign_root(e,cabinet_id)
      cabinet_id
    end
    # Gán id gốc, id từng cấu kiện và thông số cho tủ vừa dựng (cả definition lẫn instance).
    def stamp_cabinet(instance,p,cabinet_id)
      ModelData.stamp(instance,cabinet_id)
      set_cabinet_params(instance.definition,p,cabinet_id)
      set_cabinet_params(instance,p,cabinet_id)
    end
    def cabinet_layer(model)
      model.layers['VGD_CABINET'] || model.layers.add('VGD_CABINET')
    end
    # Hệ trục chuẩn hóa của tủ tại vị trí hiện tại, xoay thêm stamp_angle của tủ T+/VGD cũ nếu có.
    def cabinet_frame_transformation(instance)
      transform=instance.transformation
      axes=[transform.xaxis,transform.yaxis,transform.zaxis].map(&:normalize)
      definition=instance.definition
      stamp=(definition.get_attribute('VGD_Cabinet','stamp_angle',nil) || definition.get_attribute('TPlus_Cabinet','stamp_angle','0')).to_f
      frame=Geom::Transformation.axes(transform.origin,*axes)
      stamp.abs > 1e-8 ? frame * Geom::Transformation.rotation(ORIGIN,Z_AXIS,stamp) : frame
    end
    # Dựng definition và instance tủ mới từ thông số đã chuẩn hóa. Gọi bên trong operation của SketchUp.
    def build_cabinet_instance(model,p,transform)
      definition=model.definitions.add('VGD_CABINET')
      draw_geometry(definition.entities,p)
      cabinet_id=SecureRandom.uuid
      inst=model.active_entities.add_instance(definition,transform)
      inst.name='Tủ VGD'
      inst.layer=cabinet_layer(model)
      stamp_cabinet(inst,p,cabinet_id)
      inst
    end
    # Dựng lại hình học của tủ đã có (giữ trục và vị trí) rồi gán lại id, thông số. Gọi bên trong operation.
    def rebuild_cabinet(model,instance,p,cabinet_id)
      instance.make_unique if instance.definition.instances.size > 1
      definition=instance.definition
      instance.transformation=cabinet_frame_transformation(instance)
      definition.entities.clear!; draw_geometry(definition.entities,p)
      definition.delete_attribute('VGD_Cabinet','stamp_angle')
      definition.delete_attribute('TPlus_Cabinet','stamp_angle')
      stamp_cabinet(instance,p,cabinet_id)
      instance.layer=cabinet_layer(model)
    end
    def report_error(e)
      text=e.is_a?(ModelingRules::Invalid) ? e.message : "Không dựng được tủ: #{e.message}"
      puts "VGD Cabinet #{e.class}: #{e.message}\n#{Array(e.backtrace).first(5).join("\n")}" unless e.is_a?(ModelingRules::Invalid)
      dialog_visible? ? @dialog.execute_script("showModelStatus(#{text.to_json},true);") : UI.messagebox(text)
      nil
    end
    def normalize(p); ModelingRules.normalize(p,default_params); end
    def draw_geometry(entities,p); Modeling.draw(entities,p); end
    def create_new_cabinet(p)
      Sketchup.active_model.select_tool(PlacementTool.new(normalize(p)))
    rescue => e
      report_error(e)
    end
    def create_new_cabinet_at(p,transform)
      p=normalize(p); model=Sketchup.active_model
      @busy=true; active_tag=model.active_layer; started=false
      begin
        model.start_operation('VGD Dựng tủ',true); started=true
        model.active_layer=model.layers[0]
        tr=transform.is_a?(Geom::Transformation) ? transform : Geom::Transformation.new(transform)
        inst=build_cabinet_instance(model,p,tr)
        model.selection.clear; model.selection.add(inst)
        model.commit_operation; started=false
      rescue => e
        model.abort_operation if started
        return report_error(e)
      ensure
        model.active_layer=active_tag; @busy=false
      end
      @description_draft=false
      @dialog.execute_script('leaveDescriptionDraft();') if dialog_visible?
      sync_current_selection
      inst
    rescue => e
      report_error(e)
    end
    def update_selected_cabinet(input)
      raise ModelingRules::Invalid,'Đang tạo tủ từ mô tả. Bấm Trở lại tủ đang chọn trước khi cập nhật.' if @description_draft
      model=Sketchup.active_model; inst=find_cabinet_instance
      raise ModelingRules::Invalid,'Chọn đúng một tủ VGD để cập nhật. Dùng ĐẶT TỦ MỚI để tạo tủ.' unless inst
      raise ModelingRules::Invalid,'Tủ đang khóa. Hãy mở khóa trước khi sửa.' if inst.locked?
      raise ModelingRules::Invalid,'Đã đổi file SketchUp. Mở lại bảng VGD để đọc tủ của file hiện tại.' unless input['__model_guid'].to_s == model.guid.to_s
      raise ModelingRules::Invalid,'Đối tượng chọn đã thay đổi. Hãy sửa lại thông số của tủ đang chọn.' unless input['__target_pid'].to_s == inst.persistent_id.to_s
      p=normalize(input)
      problem=ModelingRules.axes_problem(inst.transformation)
      raise ModelingRules::Invalid,'Tủ có tỷ lệ bằng 0; khôi phục Scale trước khi sửa.' if problem==:zero_scale
      raise ModelingRules::Invalid,'Tủ bị xiên (skew); khôi phục phép biến đổi trước khi sửa.' if problem==:skewed
      cabinet_id=ModelData.cabinet_id(inst) || SecureRandom.uuid
      @busy=true; active_tag=model.active_layer; started=false
      begin
        model.start_operation('VGD Cập nhật tủ',true); started=true
        model.active_layer=model.layers[0]
        rebuild_cabinet(model,inst,p,cabinet_id)
        model.commit_operation; started=false
      rescue => e
        model.abort_operation if started
        return report_error(e)
      ensure
        model.active_layer=active_tag; @busy=false
      end
      sync_current_selection
    rescue => e
      report_error(e)
    end
    def preview_selected_update(input)
      raise ModelingRules::Invalid,'Đang tạo tủ từ mô tả. Bấm Trở lại tủ đang chọn trước khi cập nhật.' if @description_draft
      model=Sketchup.active_model; inst=find_cabinet_instance
      raise ModelingRules::Invalid,'Chọn đúng một tủ VGD để xem trước cập nhật.' unless inst
      raise ModelingRules::Invalid,'Tủ đang khóa. Hãy mở khóa trước khi sửa.' if inst.locked?
      raise ModelingRules::Invalid,'Đã đổi file SketchUp. Mở lại bảng VGD để đọc tủ của file hiện tại.' unless input['__model_guid'].to_s==model.guid.to_s
      raise ModelingRules::Invalid,'Đối tượng chọn đã thay đổi. Hãy chọn lại tủ trước khi xem trước.' unless input['__target_pid'].to_s==inst.persistent_id.to_s
      mesh=PreviewMesh.new(normalize(input))
      model.select_tool(UpdatePreviewTool.new(inst.persistent_id,model.guid,input,mesh))
    rescue => e
      report_error(e)
    end
    def batch_params_for(current, input, scale = [1.0, 1.0, 1.0])
      params = current.dup
      params['w'] = params['w'].to_f * scale[0]
      params['d'] = params['d'].to_f * scale[1]
      params['h'] = params['h'].to_f * scale[2]
      if params['module_mode'] == 'Độc lập' && !params['module_widths'].to_s.strip.empty?
        params['module_widths'] = ModelingRules.widths(params).map { |width| (width * scale[0]).round(3) }.join(';')
      end
      FRONT_SETTING_KEYS.each { |key| params[key] = input[key] if input.key?(key) }
      normalize(params)
    end
    def preview_batch_front_settings(input)
      model = Sketchup.active_model
      selection = model.selection.to_a
      targets = selection.select { |entity| is_cabinet_entity?(entity) }
      raise ModelingRules::Invalid, 'Chọn từ hai tủ VGD trở lên để áp dụng hàng loạt.' if targets.size < 2
      raise ModelingRules::Invalid, 'Bỏ khóa các tủ trước khi áp dụng.' if targets.any?(&:locked?)
      raise ModelingRules::Invalid, 'Các tủ phải cùng nằm trong ngữ cảnh chỉnh sửa hiện tại.' unless targets.all? { |entity| model.active_entities.include?(entity) }
      records = targets.map do |instance|
        current = get_cabinet_params(instance)
        raise ModelingRules::Invalid, 'Có tủ được chọn không có thông số VGD; bỏ tủ đó khỏi vùng chọn.' unless current
        transform = instance.transformation
        raise ModelingRules::Invalid, 'Có tủ bị scale bằng 0 hoặc xiên; khôi phục trục trước khi cập nhật.' if ModelingRules.axes_problem(transform)
        scale = [transform.xaxis, transform.yaxis, transform.zaxis].map(&:length)
        params = batch_params_for(current,input,scale)
        { instance: instance, params: params, mesh: PreviewMesh.new(params), transform: cabinet_frame_transformation(instance) }
      end
      model.select_tool(BatchUpdatePreviewTool.new(records, model.guid))
    rescue => error
      report_error(error)
    end
    def apply_batch_front_settings(items, model_guid)
      model = Sketchup.active_model
      raise ModelingRules::Invalid, 'Đã đổi file SketchUp; lô cập nhật đã hủy.' unless model.guid.to_s == model_guid.to_s
      raise ModelingRules::Invalid, 'Một tủ đã bị xóa hoặc bỏ chọn; lô cập nhật đã hủy.' unless items.all? { |pid,_| (instance = model.find_entity_by_persistent_id(pid.to_i)) && instance.valid? && model.selection.include?(instance) && !instance.locked? }
      started = false; @busy = true; active_tag = model.active_layer
      begin
        model.start_operation('VGD Cập nhật hàng loạt cánh và hộc', true); started = true
        model.active_layer = model.layers[0]
        items.each do |pid, params|
          instance = model.find_entity_by_persistent_id(pid.to_i)
          cabinet_id = ModelData.cabinet_id(instance) || SecureRandom.uuid
          rebuild_cabinet(model, instance, params, cabinet_id)
        end
        model.commit_operation; started = false
      rescue => error
        model.abort_operation if started
        raise error
      ensure
        model.active_layer = active_tag; @busy = false
      end
      sync_current_selection
      true
    rescue => error
      report_error(error)
    end
    def start_box_conversion(input)
      model=Sketchup.active_model
      selection=model.selection.to_a
      targets=selection.select { |entity| (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)) && !is_cabinet_entity?(entity) }
      raise ModelingRules::Invalid,'Chọn một hoặc nhiều nhóm/component hộp để chuyển thành tủ.' if targets.empty?
      raise ModelingRules::Invalid,'Chỉ chọn các group/component hộp; bỏ các mặt, cạnh hoặc cabinet VGD khỏi lựa chọn.' unless targets.size==selection.size
      raise ModelingRules::Invalid,'Bỏ khóa các hộp trước khi chuyển.' if targets.any?(&:locked?)
      raise ModelingRules::Invalid,'Chỉ chuyển các hộp đang nằm trong cùng ngữ cảnh chỉnh sửa.' unless targets.all? { |entity| model.active_entities.include?(entity) }
      model.select_tool(BoxToCabinetTool.new(input,targets))
    rescue => e
      report_error(e)
    end
    def apply_box_conversion(records,model_guid)
      model=Sketchup.active_model
      raise ModelingRules::Invalid,'Đã đổi file SketchUp; lô chuyển đổi đã hủy.' unless model.guid.to_s==model_guid.to_s
      raise ModelingRules::Invalid,'Hãy chọn lại hộp; lựa chọn đã thay đổi.' unless records.all? { |record| record.source.valid? && model.selection.include?(record.source) && !record.source.locked? }
      started=false; @busy=true; active_tag=model.active_layer
      begin
        model.start_operation('VGD Chuyển hộp thành tủ',true); started=true
        model.active_layer=model.layers[0]
        cabinets=[]
        records.each do |record|
          inst=build_cabinet_instance(model,record.params,record.transform)
          cabinets << inst
          record.source.erase!
        end
        model.selection.clear; cabinets.each { |inst| model.selection.add(inst) }
        model.commit_operation; started=false
      rescue => e
        model.abort_operation if started
        raise e
      ensure
        model.active_layer=active_tag; @busy=false
      end
      sync_current_selection if cabinets.size==1
      cabinets
    rescue => e
      report_error(e)
    end
    def send_params_to_ui(p)
      @dialog.execute_script("updateFormFromRuby(#{p.to_json});") if dialog_visible?
    end
    def sync_current_selection
      return if @busy || @description_draft || !dialog_visible?
      inst=find_cabinet_instance
      unless inst
        @dialog.execute_script('setSelectedCabinet(null);'); return
      end
      p=get_cabinet_params(inst); return unless p
      p=default_params.merge(ModelingRules.migrate(p)); tr=inst.transformation
      p['w']*=tr.xaxis.length; p['d']*=tr.yaxis.length; p['h']*=tr.zaxis.length
      p['__target_pid']=inst.persistent_id.to_s
      p['__model_guid']=Sketchup.active_model.guid.to_s
      send_params_to_ui(p)
    end
    def preview_description(data)
      @description_preview=nil
      result=DescriptionImport.parse(data.fetch('text'))
      @description_preview={'text'=>data['text'],'request_id'=>data['request_id'],'result'=>result}
      @dialog.execute_script("receiveDescriptionPreview(#{data['request_id'].to_json},#{result.to_json});")
    rescue => e
      @dialog.execute_script("receiveDescriptionPreview(#{(data.is_a?(Hash) ? data['request_id'] : nil).to_json},#{ {'error'=>e.message}.to_json});") if dialog_visible?
    end
    def apply_description(data)
      cached=@description_preview
      raise ModelingRules::Invalid,'Mô tả đã đổi; hãy Kiểm tra lại.' unless cached && data.is_a?(Hash) && cached['text']==data['text'] && cached['request_id']==data['request_id']
      result=DescriptionImport.for_apply(data['text'],allow_partial:data['allow_partial'],acknowledged_features:data['acknowledged_features'])
      @description_draft=true
      @dialog.execute_script("applyDescriptionDraft(#{result['parameters'].to_json},#{result['unsupported_features'].to_json});")
    rescue => e
      report_error(e)
    end
    def leave_description_draft
      @description_draft=false
      @dialog.execute_script('leaveDescriptionDraft();') if dialog_visible?
      send_params_to_ui(default_params.merge('__target_pid'=>nil,'__model_guid'=>nil)) unless find_cabinet_instance
      sync_current_selection
    end
    def builtin_presets
      {
        'Tủ áo 800' => default_params.merge('d'=>600,'shelf_count'=>1),
        'Tủ áo 3 module độc lập' => default_params.merge('w'=>2400,'module_mode'=>'Độc lập','module_widths'=>'800;800;800','shelf_count'=>1),
        'Tủ áo hai tầng' => default_params.merge('w'=>1600,'h'=>2700,'is_overheight'=>true,'h_bottom'=>2100,'module_mode'=>'Độc lập','module_widths'=>'800;800','shelf_count'=>1,'shelf_count_top'=>1),
        'Tủ bếp dưới' => default_params.merge('h'=>810,'shadow_gap_h'=>0,'plinth_h'=>100,'opt_door'=>'Cánh Phủ toàn bộ'),
        'Tủ 3 hộc kéo lộ' => default_params.merge('h'=>810,'shadow_gap_h'=>0,'opt_door'=>'Không Cánh','opt_drawer'=>'Lộ','is_full_drawer'=>true,'drawer_count'=>3),
        'Tủ hộc kéo âm' => default_params.merge('t'=>20,'opt_drawer'=>'Âm','drawer_hinge_sp'=>50,'drawer_inner_offset'=>50,'drawer_count'=>2),
        'Kệ mở' => default_params.merge('h'=>1200,'d'=>350,'shadow_gap_h'=>0,'opt_door'=>'Không Cánh','shelf_count'=>3)
      }
    end
    def preset_store
      path=File.join(ENV['APPDATA'] || File.join(Dir.home,'Library','Application Support'),
        'VGD','SketchUp','VGD_Cabinet','presets_v1.json')
      @preset_store ||= PresetStore.new(path, defaults: -> { builtin_presets }, legacy: -> { legacy_presets(path) })
    end
    def legacy_presets(path)
      # Read-only migration. Preserve malformed old data rather than blocking the UI.
      raw=Sketchup.read_default('TPlus_Cabinet','presets_v43','{}').to_s
      parsed=JSON.parse(raw)
      raise ArgumentError,'Mẫu T+ cũ sai định dạng.' unless parsed.is_a?(Hash)
      parsed
    rescue JSON::ParserError, ArgumentError => error
      backup=path+'.tplus-unreadable-'+SecureRandom.hex(4)+'.txt'
      File.open(backup,'wx') { |f| f.write(raw); f.flush; f.fsync }
      @preset_migration_warning="Mẫu T+ cũ không đọc được; đã giữ dữ liệu gốc tại #{backup}. Các mẫu mới vẫn lưu được."
      puts "VGD_Cabinet: #{@preset_migration_warning} (#{error.message})"
      {}
    end
    def presets
      preset_store.load
    end
    def send_presets(selected=nil,selected_group=nil)
      return unless dialog_visible?
      values,groups,preset_groups=preset_store.snapshot
      @dialog.execute_script("updatePresetList(#{values.to_json},#{selected.to_json},#{groups.to_json},#{preset_groups.to_json},#{selected_group.to_json});")
    end
    def library_store
      root=File.join(ENV['APPDATA'] || File.join(Dir.home,'Library','Application Support'),'VGD','SketchUp','VGD_Cabinet','library')
      @library_store ||= LibraryStore.new(root)
    end
    def send_library
      @dialog.execute_script("receiveLibrary(#{library_store.listing.to_json});") if dialog_visible?
    end
    def save_library(data)
      model=Sketchup.active_model; inst=find_cabinet_instance
      raise ModelingRules::Invalid,'Chọn đúng một tủ VGD đã vẽ để lưu vào Thư viện.' unless inst
      raise ModelingRules::Invalid,'Tủ đang chọn đã đổi; chọn lại trước khi lưu.' unless data['__model_guid'].to_s==model.guid.to_s && data['__target_pid'].to_s==inst.persistent_id.to_s
      p=normalize(get_cabinet_params(inst))
      axes=[inst.transformation.xaxis,inst.transformation.yaxis,inst.transformation.zaxis]
      raise ModelingRules::Invalid,'Tủ có Scale bằng 0 hoặc bị xiên; khôi phục trước khi lưu.' if ModelingRules.axes_problem(inst.transformation)
      scale=axes.map(&:length); scale[0]*=-1 if axes[0].cross(axes[1]).dot(axes[2])<0
      library_store.save(data['name'],inst.definition,p,scale,VERSION,data['replace']==true)
      send_library
      @dialog.execute_script("selectLibrary(#{data['name'].to_s.strip.to_json});showModelStatus('Đã lưu hình học tủ vào Thư viện.',false);") if dialog_visible?
    rescue => e
      report_error(e)
    end
    def place_library_cabinet(entry,name,transform)
      model=Sketchup.active_model; active_tag=model.active_layer; started=false; @busy=true
      begin
        model.start_operation('VGD Đặt tủ từ Thư viện',true); started=true; model.active_layer=model.layers[0]
        definition=library_store.with_load_copy(entry) { |path| model.definitions.load(path) }
        raise ModelingRules::Invalid,'SketchUp không nạp được mẫu thư viện.' unless definition
        scale=Geom::Transformation.scaling(*entry.fetch('scale',[1,1,1]))
        inst=model.active_entities.add_instance(definition,transform*scale)
        inst.make_unique
        inst.name=name; inst.layer=cabinet_layer(model)
        cabinet_id=SecureRandom.uuid
        set_cabinet_params(inst,entry.fetch('params'),cabinet_id)
        ModelData.assign_parts(definition.entities,cabinet_id)
        model.selection.clear; model.selection.add(inst)
        model.commit_operation; started=false
      rescue => e
        model.abort_operation if started
        return report_error(e)
      ensure
        model.active_layer=active_tag; @busy=false
      end
      @description_draft=false
      @dialog.execute_script('leaveDescriptionDraft();') if dialog_visible?
      sync_current_selection
      inst
    end
    def show_dialog
      if dialog_visible?
        if @observed_model != Sketchup.active_model
          @observed_model.selection.remove_observer(@observer) rescue nil
          @observed_model=Sketchup.active_model
          @observed_model.selection.add_observer(@observer)
        end
        @dialog.bring_to_front; sync_current_selection; return
      end
      @dialog=UI::HtmlDialog.new(dialog_title:"VGD_Cabinet #{VERSION} — Dựng hình",preferences_key:'VGD_Cabinet.Modeling43Menu.v2',scrollable:false,resizable:true,width:500,height:560,min_width:440,min_height:420,style:UI::HtmlDialog::STYLE_DIALOG)
      @description_draft=false; @description_preview=nil
      @dialog.set_html(UIRenderer.render(default_params,presets,default_params))
      @observed_model=Sketchup.active_model; @observer=CabinetSelectionObserver.new
      @observed_model.selection.add_observer(@observer)
      current_dialog=@dialog; observed_model=@observed_model; observer=@observer
      @dialog.set_on_closed do
        observed_model.selection.remove_observer(observer) rescue nil
        if @dialog.equal?(current_dialog)
          @dialog=nil; @observed_model=nil; @observer=nil
          @description_draft=false; @description_preview=nil
        end
      end
      @dialog.add_action_callback('ready') do
        @dialog.execute_script("receiveDescriptionContract(#{DescriptionImport.contract.to_json});")
        send_presets
        sync_current_selection
        send_library
        @dialog.execute_script("showModelStatus(#{@preset_migration_warning.to_json},true);") if @preset_migration_warning
      end
      @dialog.add_action_callback('create_cabinet') { |_,p| create_new_cabinet(p) }
      @dialog.add_action_callback('refresh_library') { send_library }
      @dialog.add_action_callback('save_library') { |_,data| save_library(data) }
      @dialog.add_action_callback('library_preview') do |_,name|
        begin
          entry=library_store.entry(name)
          @dialog.execute_script("receiveLibraryPreview(#{name.to_json},#{library_store.thumbnail(entry).to_json});")
        rescue => e
          report_error(e)
        end
      end
      @dialog.add_action_callback('place_library') do |_,name|
        begin
          entry=library_store.entry(name)
          Sketchup.active_model.select_tool(PlacementTool.new(entry.fetch('params'),name))
        rescue => e
          report_error(e)
        end
      end
      @dialog.add_action_callback('rename_library') do |_,data|
        begin
          library_store.rename(data['name'],data['source_name']); send_library
          @dialog.execute_script("selectLibrary(#{data['name'].to_s.strip.to_json});")
        rescue => e
          report_error(e)
        end
      end
      @dialog.add_action_callback('delete_library') do |_,name|
        begin
          library_store.delete(name); send_library
        rescue => e
          report_error(e)
        end
      end
      @dialog.add_action_callback('preview_description') { |_,data| preview_description(data) }
      @dialog.add_action_callback('apply_description') { |_,data| apply_description(data) }
      @dialog.add_action_callback('leave_description_draft') { |_,_| leave_description_draft }
      @dialog.add_action_callback('update_cabinet') { |_,p| preview_selected_update(p) }
      @dialog.add_action_callback('batch_front_settings') { |_,p| preview_batch_front_settings(p) }
      @dialog.add_action_callback('draw_cabinet_tool') do |_,p|
        begin
          Sketchup.active_model.select_tool(CabinetDrawTool.new(normalize(p)))
        rescue => e
          report_error(e)
        end
      end
      @dialog.add_action_callback('box_to_cabinet') { |_,p| start_box_conversion(p) }
      @dialog.add_action_callback('save_preset') do |_,data|
        begin
          raise ModelingRules::Invalid,'Dữ liệu mẫu không hợp lệ.' unless data.is_a?(Hash)
          action=data['action'] || 'create'
          raise ModelingRules::Invalid,'Chọn Tạo mới, Cập nhật hoặc Đổi tên.' unless %w[create update rename].include?(action)
          params=%w[create update].include?(action) ? normalize(data['params']) : nil
          preset_store.change(action,data['name'],data['source_name'],params,data['group'])
          send_presets(data['name'].to_s.strip,data['group'])
          @dialog.execute_script("document.getElementById('preset_name').value='';showModelStatus('Đã lưu mẫu.',false);")
        rescue => e
          report_error(e)
        end
      end
      @dialog.add_action_callback('delete_preset') do |_,name|
        begin
          preset_store.change('delete',name)
          send_presets('')
        rescue => e
          report_error(e)
        end
      end
      @dialog.add_action_callback('preset_group') do |_,data|
        begin
          action=data['action']
          if action=='assign'
            preset_store.assign_group(data['preset_name'],data['group'])
          else
            preset_store.change_group(action,data['name'],data['source_name'])
          end
          selected_group=action=='delete' ? 'Chưa phân nhóm' : (data['group'] || data['name'])
          send_presets(data['preset_name'],selected_group)
          @dialog.execute_script("showModelStatus('Đã cập nhật nhóm preset.',false);")
        rescue => e
          report_error(e)
        end
      end
      @dialog.show
    end
  end
  def self.install_commands
    return if @commands_installed
    existing_toolbar=@toolbar
    existing_commands=[]
    existing_toolbar.each { |item| existing_commands << item if item.is_a?(UI::Command) } if existing_toolbar
    command=existing_commands.find { |item| item.menu_text.include?('Dựng hình') }
    unless command
      command=UI::Command.new('VGD Cabinet — Dựng hình') { show_dialog }
      UI.menu('Extensions').add_item(command)
    end
    icon=File.join(__dir__.dup.force_encoding(Encoding::UTF_8),'cabinet.svg')
    command.small_icon=icon; command.large_icon=icon
    command.tooltip="VGD Cabinet #{VERSION} — Dựng hình kỹ thuật"
    reload_command=UI::Command.new('VGD — Nạp lại mã (Reload)') { reload_extension }
    reload_command.tooltip='Nạp lại riêng mã Ruby và giao diện VGD Cabinet'
    reload_command.status_bar_text='Sau khi đồng bộ mã: thoát công cụ đang vẽ, bấm Reload để nhận bản cập nhật VGD Cabinet'
    menu=UI.menu('Extensions').add_submenu('VGD Cabinet')
    menu.add_item(reload_command)
    ::VGD::UpdateNotice.start('vgd-cabinet', 'VGD Cabinet', VERSION)
    @toolbar ||= UI::Toolbar.new('VGD Cabinet — Dựng hình')
    @toolbar.add_item(command) unless existing_commands.include?(command)
    @toolbar.restore
    unless file_loaded?(__FILE__)
      UI.add_context_menu_handler do |context_menu|
        context_menu.add_item('VGD — Sửa tủ đang chọn') { show_dialog } if find_cabinet_instance
      end
      file_loaded(__FILE__)
    end
    @commands_installed=true
    @reload_command=reload_command
  end
  install_commands if @toolbar || !file_loaded?(__FILE__)
end
