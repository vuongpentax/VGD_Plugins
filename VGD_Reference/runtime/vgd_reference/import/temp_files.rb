require 'tmpdir'
require 'fileutils'

module VGD
  module Reference
    module TempFiles
      module_function

      def session_directory
        @session_directory ||= begin
          base = if defined?(Sketchup) && Sketchup.respond_to?(:temp_dir)
                   Sketchup.temp_dir
                 else
                   Dir.tmpdir
                 end
          Dir.mktmpdir("#{TEMP_PREFIX}-", base)
        end
      end

      def write_bytes(name, bytes, extension)
        safe_name = File.basename(name.to_s).gsub(/[^\p{Alnum}._-]+/u, '_')
        safe_name = safe_name.each_char.take(96).join
        safe_name = 'reference' if safe_name.empty? || safe_name == '.'
        path = File.join(session_directory, "#{safe_name}-#{rand(1_000_000_000)}#{extension}")
        File.open(path, 'wb') { |file| file.write(bytes) }
        @paths ||= {}
        @paths[path] = true
        path
      end

      def release(path)
        path = File.expand_path(path.to_s)
        return false unless @paths && @paths.delete(path)
        File.delete(path) if File.file?(path)
        true
      rescue StandardError => error
        ImageLoader.log_error('Temporary file cleanup failed', error)
        false
      end

      def cleanup
        directory = @session_directory
        return unless directory
        FileUtils.remove_entry_secure(directory) if File.directory?(directory)
        @session_directory = nil
        @paths = {}
      rescue StandardError => error
        ImageLoader.log_error('Temporary folder cleanup failed', error)
      end
    end
  end
end
