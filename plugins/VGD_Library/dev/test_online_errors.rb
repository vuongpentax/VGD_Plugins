# Regression for the Drive HTML response collapsing the entire library window.
online = VGD::Library::Online
drive = VGD::Library::Drive
library = VGD::Library
catalog = VGD::Library::Catalog
saved_roots, saved_sources = catalog.roots, online.sources
drive_info = drive.source
folder_url = drive_info.fetch('url')
folder_id = drive.folder_id(folder_url)
assert(drive.folder_id("https://drive.google.com/open?id=#{folder_id}&usp=drive_fs")==folder_id, 'Drive open link not recognized')
assert(drive.folder_id("https://drive.google.com/drive/u/0/folders/#{folder_id}/")==folder_id, 'Drive folder URL variants not recognized')
assert(!drive.folder_id("https://example.test/drive/folders/#{folder_id}"), 'Non-Drive host treated as Drive')
html_path = '/workspace/outputs/drive_response.html'
html = File.file?(html_path) ? File.binread(html_path).force_encoding(Encoding::UTF_8) : '<!DOCTYPE html><html><body>' + '<div>Drive folder</div>' * 50000 + '</body></html>'
rejects('trang web') { online.manifest(html, {'url'=>'https://example.test/html'}) }
rejects('Không đọc được danh mục JSON') { online.parse_catalog('bad response ' * 10000) }
rejects('đối tượng JSON') { online.parse_catalog('[]') }
rejects('quá lớn') { online.parse_catalog('x' * (online::MAX_CATALOG + 1)) }
assert(library.feedback_text('Nguồn online: '+html).length<150, 'HTML response leaked through Ruby status helper')
assert(library.feedback_text('x' * 10000).length<=500, 'Ruby status helper does not bound long messages')
assert(library.error_text(JSON::ParserError.new(html)).length<150, 'Raw JSON parser response exposed to dialog')
rejects('Link thư mục Drive') { online.catalog_url(folder_url) }
assert(online.catalog_url('https://example.test/catalog.json')=='https://example.test/catalog.json', 'Valid JSON source URL changed')

drive.singleton_class.alias_method :source_before_html_test, :source
online.singleton_class.alias_method :request_before_html_test, :request
begin
  drive.define_singleton_method(:source) { drive_info.merge('local_candidates'=>['/fixture/library']) }
  catalog.save('folders', [])
  remote = {'url'=>'https://example.test/good.json'}
  catalog.save('online_sources', [{'url'=>folder_url}, remote])
  library.instance_variable_set(:@dialog, RegressionDialog.new)
  library.scan
  assert(catalog.roots==['/fixture/library'] && online.sources==[remote], 'Scan did not migrate mistaken Drive source into synced local library')
  library.stop_scan
  library.instance_variable_set(:@dialog,nil)
  3.times { drive.migrate_sources }
  assert(catalog.roots==['/fixture/library'] && online.sources==[remote], 'Migration duplicated folders or removed a valid JSON source')
  assert(online.add("https://drive.google.com/open?id=#{folder_id}") && online.sources==[remote], 'Adding known Drive link stored HTML page as JSON source')
  rejects('Link thư mục Drive') { online.add('https://drive.google.com/drive/folders/other-folder') }

  drive.define_singleton_method(:source) { drive_info.merge('local_candidates'=>[]) }
  catalog.save('online_sources', [{'url'=>folder_url}, {'url'=>'https://example.test/html'}, remote])
  drive.migrate_sources
  assert(online.sources.length==3, 'Offline sync path silently removed saved Drive source')
  requests = []
  online.define_singleton_method(:request) do |url, _limit, &callback|
    requests << url
    callback.call(url.end_with?('/html') ? html : JSON.generate({'items'=>[{'name'=>'Oak','url'=>'https://example.test/wood.png','format'=>'PNG','sha256'=>'a'*64}]}), nil)
  end
  events = []
  online.refresh { |items, warnings, done| events << [items,warnings,done] }
  assert(requests==['https://example.test/html','https://example.test/good.json'], 'Drive folder HTML was still fetched as a JSON catalog')
  assert(events.length==4 && events.last[2] && events.sum { |event| event[0].size }==1, 'Bad source prevented valid source or scan completion')
  warnings = events.flat_map { |event| event[1] }
  assert(warnings.size==2 && warnings.all? { |message| message.size<200 && !message.include?('<html') }, 'Source errors included response bodies')
  cache = File.join(VGD::Library::Storage.dir('online'), Digest::SHA256.hexdigest('https://example.test/html')+'.json')
  assert(!File.file?(cache), 'HTML response cached as valid catalog')
ensure
  drive.singleton_class.alias_method :source, :source_before_html_test
  online.singleton_class.alias_method :request, :request_before_html_test
  library.stop_scan
  library.instance_variable_set(:@dialog,nil)
  catalog.save('folders',saved_roots)
  catalog.save('online_sources',saved_sources)
end
puts 'PASS: actual Drive HTML rejected without body leak; known Drive source migrates on scan to synced local root once; offline source skipped without HTTP/picker; valid JSON sources still load and complete.'
