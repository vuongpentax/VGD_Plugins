require 'uri'
# Drag-and-drop from web pages: format sniffing and candidate fallback.
# Simulation only: Sketchup::Http is replaced by scripted responses.
unless defined?(Sketchup::Http)
  module Sketchup
    module Http
      GET = :get
      class Request
        attr_accessor :headers
        @@script = {}
        def self.script=(value); @@script = value; end
        def initialize(url, _verb); @url = url; end
        def start
          status, headers, body = @@script.fetch(@url)
          Resp.new(status, headers, body).tap { |resp| yield self, resp }
        end
        Resp = Struct.new(:status, :headers, :body) do
          def status_code; status; end
        end
      end
    end
  end
end
module UI
  def self.start_timer(*) 1 end unless respond_to?(:start_timer)
  def self.stop_timer(*) nil end unless respond_to?(:stop_timer)
end

def run_drop_tests
  mod = VGD_ImageImporter
  original_fetch = mod.method(:fetch_web_image)
  original_store = mod.method(:store_dropped)
  png = "\x89PNG\r\n\x1a\n".b + ('x' * 32).b
  jpg = "\xFF\xD8\xFF\xE0".b + ('x' * 32).b
  gif = 'GIF89a'.b + ('x' * 32).b
  webp = 'RIFF'.b + [24].pack('V') + 'WEBPVP8 '.b + ('x' * 16).b
  avif = [0, 0, 0, 24].pack('N') + 'ftypavif'.b + ('x' * 16).b
  html = '<!DOCTYPE html><html><body>page</body></html>'.b
  check = ->(ok, message) { raise message unless ok }

  check.call(mod.sniff_image_extension(png) == '.png', 'PNG not recognised')
  check.call(mod.sniff_image_extension(jpg) == '.jpg', 'JPEG not recognised')
  check.call(mod.sniff_image_extension(gif) == '.gif', 'GIF not recognised')
  check.call(mod.sniff_image_extension(webp) == '.webp', 'WEBP not recognised')
  check.call(mod.sniff_image_extension(avif) == '.avif', 'AVIF not recognised')
  check.call(mod.sniff_image_extension(html).nil?, 'HTML page treated as image')
  # A page that claims to be an image must be rejected by content, not by its header.
  check.call(mod.web_image_extension(html, 'image/png', nil)[1], 'HTML accepted with image/png header')
  check.call(mod.web_image_extension(png, 'text/html', nil) == ['.png', nil], 'PNG with wrong header rejected')

  # Candidate order: a page link fails, the <img> candidate succeeds.
  responses = {
    'https://example.test/pin/1' => [html, 'text/html'],
    'https://cdn.example.test/a.jpg' => [jpg, 'image/jpeg']
  }
  tried = []
  mod.define_singleton_method(:fetch_web_image) do |url, _redirects = 0, &done|
    tried << url
    data, type = responses.fetch(url, [nil, nil])
    if data
      done.call(data, type, URI.parse(url))
    else
      done.call(nil, 'Trang web trả về lỗi HTTP 404 khi tải ảnh.', nil)
    end
  end
  stored = []
  mod.define_singleton_method(:store_dropped) { |name, data| stored << [name, data.bytesize]; true }
  mod.instance_variable_set(:@dialog, nil)
  mod.try_web_candidates(['https://example.test/pin/1', 'https://cdn.example.test/a.jpg'])
  check.call(tried == ['https://example.test/pin/1', 'https://cdn.example.test/a.jpg'], "candidate order wrong: #{tried}")
  check.call(stored.size == 1 && stored.first[0].end_with?('.jpg') && stored.first[1] == jpg.bytesize,
             "stored wrong: #{stored}")

  # Nothing usable: last error is reported, nothing stored.
  stored.clear; tried.clear
  mod.try_web_candidates(['https://example.test/none'])
  check.call(stored.empty?, 'stored a file without a valid image')


  # Restore the real download and storage before testing them directly.
  mod.define_singleton_method(:fetch_web_image, original_fetch)
  mod.define_singleton_method(:store_dropped, original_store)

  # fetch_web_image: redirects, HTTP errors and size limit, with a scripted Sketchup::Http.
  Sketchup::Http::Request.script = {
    'https://site.test/start' => [302, { 'Location' => '/img/final.png' }, nil],
    'https://site.test/img/final.png' => [200, { 'Content-Type' => 'image/png' }, png],
    'https://site.test/missing.png' => [404, {}, ''],
    'https://site.test/huge.png' => [200, {}, png + ('x' * (20 * 1024 * 1024))],
    'https://site.test/loop' => [302, { 'Location' => '/loop' }, nil]
  }
  got = nil
  mod.fetch_web_image('https://site.test/start') { |data, info, uri| got = [data, uri.to_s] }
  check.call(got && got[0] == png && got[1] == 'https://site.test/img/final.png', "redirect not followed: #{got.inspect}")
  err = nil
  mod.fetch_web_image('https://site.test/missing.png') { |data, info, _uri| err = [data, info] }
  check.call(err && err[0].nil? && err[1].include?('404'), "HTTP 404 not reported: #{err.inspect}")
  err = nil
  mod.fetch_web_image('https://site.test/huge.png') { |data, info, _uri| err = [data, info] }
  check.call(err && err[0].nil? && err[1].include?('20 MiB'), "oversize not rejected: #{err && err[1]}")
  err = nil
  mod.fetch_web_image('https://site.test/loop') { |data, info, _uri| err = [data, info] }
  check.call(err && err[0].nil?, 'redirect loop not stopped')

  # Only http and https links may be downloaded.
  check.call(mod.drop_url(['file:///C:/secret.png']) == false, 'non-http URL accepted')
  puts 'PASS: web drop — format sniffing, page-vs-image rejection, candidate fallback, scheme guard (simulation)'
end
