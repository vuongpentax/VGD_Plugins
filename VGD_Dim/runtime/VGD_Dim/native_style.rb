# encoding: UTF-8
# Windows bridge: invoke SketchUp's own Model Info update controls.
# No entity-memory editing, guessed command ids, font conversion or Select All.
module VGD
  module Dim
    module NativeStyle
      extend self
      attr_writer :adapter
      def adapter
        @adapter ||= WindowsAdapter.new
      end
      def apply(model, settings, apply_setters: true, &finished)
        raise ArgumentError, 'APPLY đang chạy.' if @job
        config = Engine.validate(settings)
        targets = Engine.selected(model)
        raise ArgumentError, 'Hãy chọn trực tiếp Dim hoặc Text/Label trước khi APPLY.' if targets.empty?
        Engine.check_context(model)
        api = adapter
        api.check_platform!
        @job = Job.new(model, config, api, finished, apply_setters)
        @job.start
      end
      def cancel
        @job.cancel if @job
      end
      def running?
        !!@job
      end
      def released(job)
        @job = nil if @job.equal?(job)
      end

      class WindowsAPI
        def initialize
          require 'fiddle'
          @dll = Fiddle.dlopen('user32.dll')
          p = Fiddle::TYPE_VOIDP; i = Fiddle::TYPE_INT; n = Fiddle::TYPE_INTPTR_T
          @functions = {
            enum_windows: function('EnumWindows', [p,n], i),
            enum_children: function('EnumChildWindows', [p,p,n], i),
            window_text: function('GetWindowTextW', [p,p,i], i),
            class_name: function('GetClassNameW', [p,p,i], i),
            process_id: function('GetWindowThreadProcessId', [p,p], i),
            valid: function('IsWindow', [p], i),
            visible: function('IsWindowVisible', [p], i),
            enabled: function('IsWindowEnabled', [p], i),
            activate: function('SetActiveWindow', [p], p),
            send_message: function('SendMessageW', [p,i,n,n], n)
          }
        end
        def function(name, args, result)
          Fiddle::Function.new(@dll[name], args, result)
        end
        def enumerate(parent = nil)
          handles = []
          callback = Fiddle::Closure::BlockCaller.new(Fiddle::TYPE_INT,
            [Fiddle::TYPE_VOIDP,Fiddle::TYPE_INTPTR_T]) do |handle, _|
              handles << handle.to_i
              1
            end
          if parent
            @functions[:enum_children].call(parent, callback, 0)
          else
            raise 'Không liệt kê được cửa sổ SketchUp.' if @functions[:enum_windows].call(callback, 0) == 0
          end
          handles
        end
        def read_string(name, handle)
          buffer = Fiddle::Pointer.malloc(1024)
          count = @functions.fetch(name).call(handle, buffer, 512)
          return '' if count <= 0
          buffer[0,count * 2].force_encoding('UTF-16LE').encode('UTF-8')
        end
        def descriptor(handle)
          pid = Fiddle::Pointer.malloc(4)
          pid[0,4] = [0].pack('L')
          @functions[:process_id].call(handle,pid)
          {
            handle: handle, pid: pid[0,4].unpack1('L'),
            text: read_string(:window_text,handle),
            class: read_string(:class_name,handle),
            valid: @functions[:valid].call(handle) != 0,
            visible: @functions[:visible].call(handle) != 0,
            enabled: @functions[:enabled].call(handle) != 0
          }
        end
        def click(dialog, button)
          @functions[:activate].call(dialog)
          @functions[:send_message].call(button, 0x00F5, 0, 0) # BM_CLICK
        end
      end

      class WindowsAdapter
        CAPTIONS = {'Dimensions'=>'Update selected dimensions','Text'=>'Update selected text'}.freeze unless const_defined?(:CAPTIONS, false)
        def initialize(api = nil)
          @api = api
        end
        def check_platform!
          raise 'Áp mẫu Model Info hiện hỗ trợ SketchUp Windows giao diện English.' unless Sketchup.platform == :platform_win
          @api ||= WindowsAPI.new
        end
        def normalized(text)
          text.to_s.delete('&').strip.downcase
        end
        def owned_visible?(item)
          item[:pid] == Process.pid && item[:valid] && item[:visible]
        end
        def find(page)
          expected = normalized(CAPTIONS.fetch(page))
          dialogs = @api.enumerate.map { |handle| @api.descriptor(handle) }.select do |item|
            owned_visible?(item) && item[:class] == '#32770' && normalized(item[:text]) == 'model info'
          end
          raise 'Có nhiều bảng Model Info; không xác định được bảng cần cập nhật.' if dialogs.length > 1
          return nil if dialogs.empty?
          dialog = dialogs.first[:handle]
          buttons = @api.enumerate(dialog).map { |handle| @api.descriptor(handle) }.select do |item|
            owned_visible?(item) && item[:enabled] && item[:class].downcase == 'button' && normalized(item[:text]) == expected
          end
          raise 'Có nhiều nút Update selected; dừng để tránh áp nhầm.' if buttons.length > 1
          buttons.empty? ? nil : [dialog,buttons.first[:handle]]
        end
        def click(page)
          pair = find(page)
          raise "Không tìm được nút #{CAPTIONS.fetch(page)}. Hãy mở Model Info (English) và kiểm tra vùng chọn." unless pair
          @api.click(*pair)
        end
      end

      class Job
        def initialize(model, config, api, finished, apply_setters=true)
          @model = model; @config = config; @api = api; @finished = finished
          @snapshot = model.selection.to_a; @path = Array(model.active_path).dup
          @expected = @snapshot.dup; @updated = []
          @apply_setters = apply_setters
          targets = Engine.selected(model)
          @stages = []
          dims = targets.select { |entity| entity.is_a?(Sketchup::Dimension) }
          texts = targets.select { |entity| entity.is_a?(Sketchup::Text) }
          @stages << ['Dimensions',dims] unless dims.empty?
          @stages << ['Text',texts] unless texts.empty?
        end
        def same_selection?
          current = @model.selection.to_a
          current.length == @expected.length && current.all? { |entity| @expected.include?(entity) }
        end
        def check_state!
          raise 'Model hoặc ngữ cảnh đang sửa đã đổi; APPLY dừng.' unless Sketchup.active_model.equal?(@model) && Array(@model.active_path) == @path
          raise 'Vùng chọn đã đổi trong lúc APPLY; hãy chọn lại và bấm APPLY.' unless same_selection?
          raise 'Đối tượng đã bị xóa trong lúc APPLY.' unless @snapshot.all?(&:valid?)
          Engine.check_context(@model)
        end
        def select(entities)
          @model.selection.clear
          @model.selection.add(entities) unless entities.empty?
          @expected = entities.dup
        end
        def defer(&block)
          @timer = UI.start_timer(0.06, false) do
            @timer = nil
            begin
              check_state!
              block.call
            rescue StandardError => error
              finish(error)
            end
          end
        end
        def start
          # Validate both native controls before dispatching either update.
          prepare(0, true)
        rescue StandardError => error
          finish(error)
        end
        def prepare(index, preflight)
          check_state!
          if index == @stages.length
            if preflight
              prepare(0, false)
            else
              select(@snapshot)
              if @apply_setters
                Engine.apply(@model, @config)
              else
                Core.tag_selected(@model)
              end
              finish(nil)
            end
            return
          end
          page, targets = @stages[index]
          select(targets)
          raise "Không mở được Model Info → #{page}." unless UI.show_model_info(page)
          wait_button(index,preflight,0)
        end
        def wait_button(index, preflight, attempts)
          page = @stages[index][0]
          defer do
            if @api.find(page)
              unless preflight
                @api.click(page)
                @updated << page
              end
              # Let SketchUp finish processing its native command before the next stage.
              defer { prepare(index + 1, preflight) }
            elsif attempts < 9
              wait_button(index,preflight,attempts + 1)
            else
              raise "Không tìm được nút Update selected ở Model Info → #{page}. Chưa chạy bước gán tag/style."
            end
          end
        end
        def restore
          if Sketchup.active_model.equal?(@model) && Array(@model.active_path) == @path && same_selection?
            select(@snapshot.select(&:valid?))
          end
        end
        def finish(error)
          return if @done
          @done = true
          UI.stop_timer(@timer) if @timer
          @timer = nil
          begin
            restore
          rescue StandardError => restore_error
            error ||= restore_error
          ensure
            NativeStyle.released(self)
          end
          if error && !@updated.empty?
            error = RuntimeError.new("Đã gọi cập nhật native #{@updated.join(' / ')}; phần còn lại dừng: #{error.message}")
          end
          @finished.call(error) if @finished
        end
        def cancel
          finish(RuntimeError.new('APPLY đã dừng khi nạp lại plugin.'))
        end
      end
    end
  end
end
