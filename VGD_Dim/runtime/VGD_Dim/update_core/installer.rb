# encoding: UTF-8
require 'tmpdir'
require 'fileutils'
require 'securerandom'
module VGD
  module Dim
    module UpdateCore
      module Installer
        extend self
        def start(info, rbz)
          plugins = Sketchup.find_support_file('Plugins')
          raise 'Không tìm thấy thư mục Plugins của SketchUp.' unless plugins && File.directory?(plugins)
          work = File.join(Dir.tmpdir, "vgd_dim_update_#{SecureRandom.hex(8)}")
          Dir.mkdir(work)
          archive = File.join(work, info['filename'])
          File.binwrite(archive, rbz)
          helper = File.join(__dir__, 'update_installer.ps1')
          raise 'Thiếu helper cài đặt updater.' unless File.file?(helper)
          args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', helper,
                  '-Archive', archive, '-Plugins', plugins, '-ExpectedSha256', info['sha256'],
                  '-ExpectedBytes', info['bytes'].to_s, '-Version', info['version']]
          pid = Process.spawn('powershell.exe', *args, :out => File::NULL, :err => File::NULL, :pgroup => true)
          Process.detach(pid)
          true
        rescue StandardError
          FileUtils.remove_entry(work) if defined?(work) && work && File.directory?(work)
          raise
        end
      end
    end
  end
end
