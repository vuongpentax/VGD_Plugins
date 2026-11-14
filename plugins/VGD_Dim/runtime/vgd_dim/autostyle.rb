# encoding: UTF-8
module VGD
  module Dim
    module AutoStyle
      extend self
      PRUNE_MIN = 256 # Watched collections tolerated before the first prune; keeps small models free of API calls.
      def load
        data=Store.read('auto',{})
        return {'enabled'=>false,'settings'=>Core.validate_settings({})} unless data.is_a?(Hash)
        {'enabled'=>data['enabled']==true,'settings'=>Core.validate_settings(data.fetch('settings',{}))}
      rescue ArgumentError
        {'enabled'=>false,'settings'=>Core.validate_settings({})}
      end
      def save(enabled,settings)
        raise ArgumentError, 'Auto-Style phải là bật/tắt.' unless [true,false].include?(enabled)
        Store.write('auto',{'enabled'=>enabled,'settings'=>settings_to_save(enabled,settings)})
        @config=load
        if enabled
          # Editing the form saves again; rebinding walks every definition, so only bind when needed.
          bind(Sketchup.active_model) unless bound_to?(Sketchup.active_model)
        else
          detach
        end
      end
      # Turning Auto-Style off must work even when the form holds a value that no longer validates.
      def settings_to_save(enabled,settings)
        Core.validate_settings(settings)
      rescue ArgumentError
        raise if enabled
        load['settings']
      end
      def bound_to?(model)
        !@model.nil? && !@entity_observer.nil? && model.equal?(@model)
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
        return unless @model && @entity_observer
        @watched ||= []
        return if @watched.include?(entities)
        prune_watched if @watched.length >= (@prune_at || PRUNE_MIN)
        attach(entities)
      end
      def attach(entities)
        entities.add_observer(@entity_observer)
        @watched << entities
      end
      # Forget collections whose owning group was erased; their observers go with them.
      # Without this the list grows with every group ever added in the session.
      # Pruning calls the API once per collection, so it only runs when the list has doubled.
      def prune_watched
        @watched.select! { |known| owner_alive?(known) }
        @prune_at = [@watched.length * 2, PRUNE_MIN].max
      end
      # An erased group or component makes `parent` raise TypeError.
      def owner_alive?(entities)
        owner = entities.parent
        !owner.respond_to?(:valid?) || owner.valid?
      rescue TypeError
        false
      end
      def bind(model)
        detach
        return unless model && @config && @config['enabled']
        @model=model; @entity_observer=EntityWatch.new; @model_observer=ModelWatch.new; @definition_observer=DefinitionWatch.new
        @watched=[]; @prune_at=nil
        attach(model.entities)
        model.definitions.each { |definition| attach(definition.entities) }
        model.add_observer(@model_observer)
        model.definitions.add_observer(@definition_observer)
      end
      # A closed or erased model/entity cannot be unobserved; that must not stop
      # the caller (bind) from attaching to the next model.
      def detach
        clear_queue
        Array(@watched).each { |entities| detach_quietly { entities.remove_observer(@entity_observer) } }
        if @model
          detach_quietly { @model.remove_observer(@model_observer) } if @model_observer
          detach_quietly { @model.definitions.remove_observer(@definition_observer) } if @definition_observer
        end
        @watched=[]; @prune_at=nil; @model=nil
      end
      def detach_quietly
        yield
      rescue StandardError
        nil
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
        # SketchUp reports additions after the operation commits, so an entity that another
        # command added and erased inside it (for example a temporary group) is already deleted.
        return unless entity.valid?
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          watch(entity.definition.entities)
        end
        return if (@depth || 0)>0 || !@config || !@config['enabled'] || !Core.kind(entity)
        @queue ||= []; @queue << entity unless @queue.include?(entity)
        @timer ||= UI.start_timer(0,false) { @timer=nil; flush }
      end
      def watch_definition(definition)
        return unless definition.valid? # Erased inside the same operation that created it.
        watch(definition.entities)
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
        def onComponentAdded(_definitions,definition); AutoStyle.watch_definition(definition); end
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
