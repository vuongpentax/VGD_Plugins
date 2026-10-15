# encoding: UTF-8
require 'json'
require 'digest'
require 'fileutils'
module VGD
  module Dim
    module UpdateCore
      module Bootstrap
        extend self
        def recover
          plugins = Sketchup.find_support_file('Plugins')
          return true unless plugins
          journal = File.join(plugins, 'vgd_dim_update.json')
          return true unless File.file?(journal)
          data = JSON.parse(File.read(journal))
          phase = data.fetch('phase')
          raise 'Unknown update transaction phase.' unless %w[prepared old_moved new_moved].include?(phase)
          plugin = File.join(plugins, 'VGD_Dim')
          backup = sibling_path!(data.fetch('backup'), plugins, /\AVGD_Dim\.backup_[0-9a-f]{32}\z/i)
          loader = File.join(plugins, 'vgd_dim.rb')
          loader_backup = data['loader_backup']
          if loader_backup
            loader_backup = sibling_path!(loader_backup, plugins, /\Avgd_dim\.backup_[0-9a-f]{32}\.rb\z/i)
          end
          expected = data.fetch('expected')
          validate_expected!(expected)
          expected_loader = data.fetch('expected_loader')
          raise 'Invalid transaction loader hash.' unless expected_loader.match?(/\A[0-9a-f]{64}\z/i)
          if phase == 'new_moved' && verified?(plugin, expected) &&
             File.file?(loader) && Digest::SHA256.file(loader).hexdigest == expected_loader.to_s.downcase
            File.delete(journal)
            return true
          end
          if File.directory?(backup)
            if File.exist?(plugin)
              failed = File.join(plugins, "VGD_Dim.failed_#{Time.now.to_i}")
              File.rename(plugin, failed)
            end
            File.rename(backup, plugin)
          elsif phase != 'prepared' || !File.directory?(plugin)
            raise 'Cannot recover VGD Dim: verified backup is missing.'
          end
          FileUtils.cp(loader_backup, loader) if loader_backup && File.file?(loader_backup)
          File.delete(journal) if File.file?(journal)
          true
        rescue StandardError => error
          Sketchup.status_text = "VGD Dim updater recovery failed: #{error.message}"
          false
        end
        def sibling_path!(path, parent, name_pattern)
          full = File.expand_path(path.to_s)
          raise 'Transaction path is outside SketchUp Plugins.' unless File.dirname(full).casecmp(File.expand_path(parent)) == 0
          raise 'Transaction backup name is invalid.' unless File.basename(full).match?(name_pattern)
          full
        end
        def validate_expected!(expected)
          raise 'Invalid transaction file list.' unless expected.is_a?(Hash) && !expected.empty?
          expected.each do |relative, sha|
            parts = relative.to_s.split(/[\\\/]/)
            raise 'Unsafe transaction path.' if relative.to_s.match?(/\A(?:[A-Za-z]:|[\\\/])/) || parts.any? { |part| part.empty? || part == '.' || part == '..' }
            raise 'Invalid transaction file hash.' unless sha.to_s.match?(/\A[0-9a-f]{64}\z/i)
          end
        end
        def verified?(root, expected)
          expected.all? do |relative, sha|
            path = File.expand_path(relative, root)
            prefix = File.expand_path(root) + File::SEPARATOR
            path.start_with?(prefix) && File.file?(path) && Digest::SHA256.file(path).hexdigest == sha.to_s.downcase
          end
        end
      end
    end
  end
end
