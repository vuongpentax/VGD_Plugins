# encoding: UTF-8
require 'json'
require 'uri'
module VGD
  module Dim
    module UpdateCore
      module Manifest
        extend self
        ID = 'vgd_dim'.freeze
        REPOSITORY = 'vuongpentax/VGD_Plugins'.freeze
        MANIFEST_URL = 'https://raw.githubusercontent.com/vuongpentax/VGD_Plugins/main/VGD_Dim/VGD_UPDATE_MANIFEST.json'.freeze
        SHA_PATTERN = /\A[0-9a-f]{64}\z/i
        def parse(body)
          data = JSON.parse(body)
          raise 'Manifest sai product_id.' unless data['product_id'] == ID
          raise 'Manifest sai tên file.' unless data['filename'].to_s.match?(/\AVGD_Dim_v[0-9A-Za-z.-]+\.rbz\z/)
          version = data['version'].to_s
          raise 'Version không hợp lệ.' unless version.match?(/\A\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?\z/)
          channel = data['channel'].to_s
          raise 'Channel không hợp lệ.' unless %w[stable beta].include?(channel)
          year = data['min_sketchup_year'].to_s
          raise 'Phiên bản SketchUp tối thiểu không hợp lệ.' unless year.match?(/\A20\d{2}\z/)
          bytes = Integer(data['bytes'])
          raise 'Kích thước RBZ không hợp lệ.' unless bytes.between?(1, 100 * 1024 * 1024)
          sha = data['sha256'].to_s.downcase
          raise 'SHA-256 không hợp lệ.' unless SHA_PATTERN.match?(sha)
          uri = URI.parse(data['download_url'])
          expected = "https://github.com/#{REPOSITORY}/releases/download/vgd-dim-v#{version}/#{data['filename']}"
          raise 'URL tải không thuộc GitHub Release đã định.' unless uri.to_s == expected
          { 'version' => version, 'channel' => channel, 'min_sketchup_year' => year,
            'filename' => data['filename'], 'bytes' => bytes, 'sha256' => sha,
            'download_url' => uri.to_s, 'changelog' => data['changelog'].to_s }
        rescue JSON::ParserError, URI::InvalidURIError, ArgumentError, TypeError => error
          raise "Manifest không hợp lệ: #{error.message}"
        end
      end
    end
  end
end
