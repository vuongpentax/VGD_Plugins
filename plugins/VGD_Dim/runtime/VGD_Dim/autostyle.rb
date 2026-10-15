# encoding: UTF-8
module VGD
  module Dim
    module AutoStyle
      extend self
      def load
        data=Store.read('auto',{})
        return {'enabled'=>false,'settings'=>Core.validate_settings({})} unless data.is_a?(Hash)
        {'enabled'=>data['enabled']==true,'settings'=>Core.validate_settings(data.fetch('settings',{}))}
      rescue ArgumentError
        {'enabled'=>false,'settings'=>Core.validate_settings({})}
      end
      def save(enabled,settings)
        raise ArgumentError, 'Auto-Style phải là bật/tắt.' unless [true,false].include?(enabled)
        Store.write('auto',{'enabled'=>enabled,'settings'=>Core.validate_settings(settings)})
        @config=load
        enabled ? bind(Sketchup.active_model) : detach
      end
      def suspend
        @depth=(@depth || 0)+1
        yield
      ensure
        @depth-=1
      end
      def clear_queue
        UI.stop_timer(@timer) if @timer
        @timer=nil; @queue=[]
      end
      def watch(entities)
        @watched ||= []
        return if @watched.include?(entities)
        entities.add_observer(@entity_observer)
        @watched << entities
      end
      def bind(model)
        detach
        return unless model && @config && @config['enabled']
        @model=model; @entity_observer=EntityWatch.new; @model_observer=ModelWatch.new; @definition_observer=DefinitionWatch.new
        watch(model.entities)
        model.definitions.each { |definition| watch(definition.entities) }
        model.add_observer(@model_observer)
        model.definitions.add_observer(@definition_observer)
      end
      def detach
        clear_queue
        Array(@watched).each { |entities| entities.remove_observer(@entity_observer) rescue nil }
        @model.remove_observer(@model_observer) if @model && @model_observer
        @model.definitions.remove_observer(@definition_observer) if @model && @definition_observer
        @watched=[]; @model=nil
      end
      def start
        @config=load
        @app_observer ||= AppWatch.new
        unless @app_registered
          Sketchup.add_observer(@app_observer); @app_registered=true
        end
        bind(Sketchup.active_model) if @config['enabled']
      end
      def shutdown
        detach
        Sketchup.remove_observer(@app_observer) if @app_registered
        @app_registered=false
      end
      def added(entity)
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          watch(entity.definition.entities)
        end
        return if (@depth || 0)>0 || !@config || !@config['enabled'] || !Core.kind(entity)
        @queue ||= []; @queue << entity unless @queue.include?(entity)
        @timer ||= UI.start_timer(0,false) { @timer=nil; flush }
      end
      def flush
        targets=@queue || []; @queue=[]
        return unless @model && Sketchup.active_model.equal?(@model) && @config && @config['enabled']
        targets=targets.select { |entity| entity.valid? && !Core.skip_hidden?(entity,{}) }
        return if targets.empty?
        suspend do
          @model.start_operation('VGD Dim — Auto-Style',true,false,true)
          begin
            targets.each do |entity|
              type=Core.kind(entity)
              type=='dim' ? Core.style_dim(entity,@config['settings'][type]) : Core.style_text(entity,@config['settings'][type],type)
            end
            @model.commit_operation
          rescue StandardError
            @model.abort_operation
            raise
          end
        end
      rescue StandardError => error
        VGD::Dim.show_error("Auto-Style: #{error.message}") if VGD::Dim.respond_to?(:show_error)
      end
      class EntityWatch < Sketchup::EntitiesObserver
        def onElementAdded(_entities,entity); AutoStyle.added(entity); end
      end
      class DefinitionWatch < Sketchup::DefinitionsObserver
        def onComponentAdded(_definitions,definition); AutoStyle.watch(definition.entities); end
      end
      class ModelWatch < Sketchup::ModelObserver
        def onTransactionUndo(_model); AutoStyle.clear_queue; end
        def onTransactionRedo(_model); AutoStyle.clear_queue; end
        def onActivePathChanged(model); AutoStyle.watch(model.active_entities); end
      end
      class AppWatch < Sketchup::AppObserver
        def expectsStartupModelNotifications; true; end
        def onNewModel(model); AutoStyle.bind(model); end
        def onOpenModel(model); AutoStyle.bind(model); end
      end
    end
  end
end
