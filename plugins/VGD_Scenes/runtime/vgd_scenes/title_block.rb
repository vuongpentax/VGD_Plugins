# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require 'fileutils'

module VGD
  module Scenes
    # Turns a title-block PDF into a PNG LayOut can place (Windows PDF engine, no extra software).
    module TitleBlock
      SCRIPT = File.join(__dir__, 'pdf_to_png.ps1').freeze
      PAPERS = { 'A4' => [297.0, 210.0], 'A3' => [420.0, 297.0], 'A2' => [594.0, 420.0], 'A1' => [841.0, 594.0] }.freeze
      TOLERANCE_MM = 3.0
      DPI = 200

      # Returns { 'pdf', 'png', 'width_mm', 'height_mm', 'paper' ('A3_L'... or nil if non-standard) }.
      def self.import(pdf_path, page = 0)
        raise ArgumentError, 'Chưa chọn file PDF khung tên.' if pdf_path.to_s.empty?
        raise ArgumentError, 'Không thấy file PDF khung tên.' unless File.file?(pdf_path)
        raise ArgumentError, 'Khung tên phải là file .pdf.' unless File.extname(pdf_path).casecmp('.pdf').zero?
        raise 'Chức năng nhập khung tên PDF hiện chỉ chạy trên Windows.' unless Gem.win_platform?
        folder = File.join(Dir.tmpdir, 'vgd-scenes-titleblock')
        FileUtils.mkdir_p(folder)
        png = File.join(folder, "#{File.basename(pdf_path, '.*').gsub(/[^\w\-]/, '_')}-#{File.mtime(pdf_path).to_i}-#{page}.png")
        info = convert(pdf_path, png, page)
        info.merge('pdf' => pdf_path, 'png' => png, 'paper' => paper_for(info['width_mm'], info['height_mm']))
      end

      def self.convert(pdf_path, png, page)
        command = ['powershell.exe', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', SCRIPT,
                   '-Pdf', pdf_path, '-Out', png, '-Page', page.to_i.to_s, '-Dpi', DPI.to_s]
        out, err, _status = Open3.capture3(*command)
        data = (JSON.parse(out.to_s.lines.last.to_s) rescue nil)
        raise "Không đọc được PDF khung tên: #{err.to_s.strip[0, 160]}" unless data
        raise "Không đọc được PDF khung tên: #{data['error']}" if data['error']
        raise 'Không tạo được ảnh khung tên.' unless File.file?(png) && File.size(png) > 0
        data
      end

      def self.paper_for(width, height)
        PAPERS.each do |name, (long, short)|
          return "#{name}_L" if (width - long).abs <= TOLERANCE_MM && (height - short).abs <= TOLERANCE_MM
          return "#{name}_P" if (width - short).abs <= TOLERANCE_MM && (height - long).abs <= TOLERANCE_MM
        end
        nil
      end
    end
  end
end
