# encoding: UTF-8
module VGD
  module Library
    module ShellSync
      class EntityObserver < Sketchup::EntityObserver
        attr_reader :model
        def initialize(model, shell)
          @model, @shell, @material = model, shell, shell.material
        end

        def onChangeEntity(entity)
          return if ShellSync.busy? || !entity.valid? || entity.material == @material
          previous, @material = @material, entity.material
          ShellSync.queue(@model, @shell, previous, @material)
        end
      end

      class ModelObserver < Sketchup::ModelObserver
        def onTransactionCommit(model)
          ShellSync.schedule(model)
        end

        def onTransactionUndo(model)
          ShellSync.reset(model)
        end

        def onTransactionRedo(model)
          ShellSync.reset(model)
        end

        def onTransactionAbort(model)
          ShellSync.reset(model)
        end

        def onDeleteModel(model)
          ShellSync.detach(model)
        end
      end

      def self.busy?
        @busy
      end

      def self.paused(model)
        previous = @busy
        @busy = true
        yield
      ensure
        @busy = previous
        reset(model) unless previous
      end

      def self.watch(model, entities, depth = 0, mark = true)
        return if depth > 64
        @watched ||= {}
        @models ||= {}
        unless @models[model.object_id]
          observer = ModelObserver.new
          model.add_observer(observer)
          @models[model.object_id] = observer
        end
        entities.each do |entity|
          next unless Tools.instance?(entity) && entity.valid? && !entity.locked?
          entity.set_attribute(Catalog::SECTION, 'follow_shell', true) if mark
          unless @watched[entity.object_id]
            observer = EntityObserver.new(model, entity)
            entity.add_observer(observer)
            @watched[entity.object_id] = [entity, observer]
          end
          watch(model, entity.definition.entities.to_a, depth + 1, mark)
        end
      end

      def self.attach_saved(model, entities, depth = 0, seen = {})
        return if depth > 64
        entities.each do |entity|
          next unless Tools.instance?(entity) && entity.valid?
          watch(model, [entity], 0, false) if entity.get_attribute(Catalog::SECTION, 'follow_shell', false)
          next if seen[entity.definition.object_id]
          seen[entity.definition.object_id] = true
          attach_saved(model, entity.definition.entities.to_a, depth + 1, seen)
        end
      end

      def self.queue(model, shell, previous, current)
        return if @busy
        (@pending ||= {})[[model.object_id, shell.object_id]] = [model, shell, previous, current]
      end

      def self.reset(model)
        @pending&.delete_if { |key, _| key[0] == model.object_id }
        # Observer instances must refresh their old-material snapshots on undo.
        (@watched || {}).each_value do |entity, observer|
          observer.instance_variable_set(:@material, entity.material) if entity.valid?
        end
      end

      def self.detach(model)
        @pending&.delete_if { |key, _| key[0] == model.object_id }
        @watched&.delete_if { |_key, pair| pair[1].model.equal?(model) }
        @models&.delete(model.object_id)
      end

      def self.schedule(model)
        return if @busy || !@pending || @pending.empty?
        Library.defer do
          next if @busy || !Sketchup.active_model.equal?(model)
          changes = @pending.select { |key, _| key[0] == model.object_id }.values
          @pending.delete_if { |key, _| key[0] == model.object_id }
          next if changes.empty?
          started = false
          begin
            @busy = true
            started = model.start_operation('VGD — Đồng bộ map theo vỏ', true, false, true)
            changes.each do |_model, shell, _old, material|
              next unless shell.valid? && !shell.locked? && shell.material == material
              shell.make_unique
              Geometry.each_face(shell.definition.entities.to_a) do |face, _|
                face.material = material
              end
              watch(model, [shell], 0, false)
            end
            model.commit_operation
          rescue StandardError => e
            # Aborting a transparent operation also aborts the native paint
            # operation it follows. Finish it and let the user Undo the edit.
            model.commit_operation if started
            Library.message("Đồng bộ map theo vỏ chưa hoàn tất: #{e.message}. Ctrl+Z để hoàn tác.", true)
          ensure
            @busy = false
            reset(model)
          end
        end
      end
    end
  end
end
