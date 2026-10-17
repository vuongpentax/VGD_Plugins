# frozen_string_literal: true

module VGD
  module Scenes
    # The only place that knows how to talk to VGD Dim. Scenes works without Dim;
    # when Dim is installed, each scene of a set can be measured automatically.
    module DimBridge
      # Cabinet face a standard view looks at (Dim face codes: normal of the face towards the viewer).
      FACES = { 'FRONT' => '-y', 'BACK' => '+y', 'RIGHT' => '+x', 'LEFT' => '-x', 'TOP' => '+z', 'BOTTOM' => '-z' }.freeze

      def self.available?
        !!(defined?(::VGD::Dim::SmartDim) && ::VGD::Dim::SmartDim.respond_to?(:run) && ::VGD::Dim::SmartDim.respond_to?(:saved))
      end

      # Dim options for one scene: the user's saved Smart Dim settings, aimed at this scene.
      # Views measure the object's face; sections measure along the cut that scene shows.
      def self.options_for(entry, saved_options)
        if entry['role'] == 'SECTION'
          saved_options.merge('face' => 'camera', 'use_section' => true, 'scene_only' => true)
        else
          saved_options.merge('face' => FACES.fetch(entry['name']), 'use_section' => false, 'scene_only' => true)
        end
      end

      def self.measurable?(entry)
        entry['role'] == 'SECTION' || FACES.key?(entry['name'])
      end

      # Measures every measurable scene in entries, one by one, with the scene open.
      # Never raises for one scene's problem; those become warnings.
      # Returns { 'measured' => n, 'skipped' => n, 'warnings' => [...] }.
      def self.apply(model, entries)
        result = { 'measured' => 0, 'skipped' => 0, 'warnings' => [] }
        unless available?
          result['skipped'] = entries.length
          result['warnings'] << 'Chưa cài VGD Dim nên chưa ghi kích thước tự động.'
          return result
        end
        if model.active_path
          result['skipped'] = entries.length
          result['warnings'] << 'Đóng edit Group/Component trước khi ghi kích thước tự động.'
          return result
        end
        dim = ::VGD::Dim::SmartDim
        saved = dim.saved
        transition = model.options['PageOptions']['ShowTransition']
        # An animated scene change would still be moving when Dim reads the camera.
        model.options['PageOptions']['ShowTransition'] = false
        begin
          entries.each do |entry|
            unless measurable?(entry)
              result['skipped'] += 1
              next
            end
            page = SceneStore.find(model, entry['id'])
            begin
              model.pages.selected_page = page
              dim.run(options_for(entry, saved['opts']), saved['settings'])
              result['measured'] += 1
            rescue StandardError => error
              result['skipped'] += 1
              result['warnings'] << "#{page.name}: chưa ghi được kích thước (#{error.message})"
            end
          end
        ensure
          model.options['PageOptions']['ShowTransition'] = transition unless transition.nil?
        end
        result
      end
    end
  end
end
