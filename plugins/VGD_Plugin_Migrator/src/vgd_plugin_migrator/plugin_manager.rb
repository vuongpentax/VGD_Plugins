# encoding: UTF-8
require 'sketchup.rb'
require 'fileutils'
require 'json'

module VGD
  module PluginMigrator
    # Quản lý bật/tắt plugin: plugin bị tắt được chuyển sang thư mục riêng
    # (không xóa), bật lại thì chuyển về Plugins. Có hiệu lực sau khi khởi động lại SketchUp.
    module Manager
      PM = VGD::PluginMigrator

      def self.year
        (2000 + Sketchup.version.to_i).to_s
      end

      def self.root_dir
        File.join(File.dirname(PM.plugins_dir(year)), 'VGD_PluginManager')
      end

      def self.disabled_dir
        File.join(root_dir, 'disabled')
      end

      def self.sets_file
        File.join(root_dir, 'sets.json')
      end

      # Gom theo tên plugin: { 'ten' => ['ten.rb', 'ten'] }
      def self.list_dir(dir)
        return {} unless File.directory?(dir)
        groups = {}
        entries = Dir.children(dir) - PM::SKIP_NAMES - PM::SELF_NAMES
        entries.reject { |e| e.start_with?('.') }.each do |e|
          key = e.sub(/\.(rb|rbe|rbs)\z/i, '')
          (groups[key] ||= []) << e
        end
        groups.each_value(&:sort!)
        groups
      end

      def self.load_sets
        return {} unless File.exist?(sets_file)
        data = JSON.parse(File.read(sets_file, encoding: 'UTF-8'))
        data.is_a?(Hash) ? data.select { |_k, v| v.is_a?(Array) } : {}
      rescue
        {}
      end

      def self.save_sets(sets)
        FileUtils.mkdir_p(root_dir)
        File.write(sets_file, JSON.pretty_generate(sets), encoding: 'UTF-8')
      end

      def self.state
        on  = list_dir(PM.plugins_dir(year))
        off = list_dir(disabled_dir)
        names = (on.keys + off.keys).uniq.sort_by(&:downcase)
        plugins = names.map do |n|
          st = if on.key?(n) && off.key?(n) then 'conflict'
               elsif on.key?(n) then 'on'
               else 'off'
               end
          { 'name' => n, 'status' => st, 'items' => (on[n] || off[n]).size }
        end
        sets = load_sets.map do |k, v|
          { 'name' => k, 'names' => v, 'count' => v.size,
            'missing' => v.count { |x| !names.include?(x) } }
        end
        { 'year' => year, 'plugins' => plugins,
          'sets' => sets.sort_by { |s| s['name'].downcase },
          'disabled_dir' => disabled_dir }
      end

      # Chuyển các mục từ thư mục này sang thư mục kia. Lỗi thì hoàn tác. Trả về nil nếu ổn.
      def self.move_items(from_dir, to_dir, items)
        moved = []
        FileUtils.mkdir_p(to_dir)
        items.each do |item|
          src = File.join(from_dir, item)
          dst = File.join(to_dir, item)
          raise "#{item} đã tồn tại ở thư mục đích" if File.exist?(dst)
          FileUtils.mv(src, dst)
          moved << item
        end
        nil
      rescue => e
        moved.each do |i|
          begin
            FileUtils.mv(File.join(to_dir, i), File.join(from_dir, i))
          rescue
            nil
          end
        end
        e.message
      end

      # action: 'disable' hoặc 'enable'. Chỉ dùng tên có trong danh sách thật.
      def self.change(names, action)
        plugins = PM.plugins_dir(year)
        on  = list_dir(plugins)
        off = list_dir(disabled_dir)
        res = { changed: [], skipped: [], errors: [] }
        Array(names).map(&:to_s).uniq.each do |n|
          if action == 'disable'
            unless on.key?(n)
              res[:skipped] << n
              next
            end
            if off.key?(n)
              res[:errors] << "#{n}: đã có bản cùng tên trong thư mục tắt, cần xử lý thủ công"
              next
            end
            err = move_items(plugins, disabled_dir, on[n])
          else
            unless off.key?(n)
              res[:skipped] << n
              next
            end
            if on.key?(n)
              res[:errors] << "#{n}: đã có bản cùng tên trong Plugins, cần xử lý thủ công"
              next
            end
            err = move_items(disabled_dir, plugins, off[n])
          end
          err ? res[:errors] << "#{n}: #{err}" : res[:changed] << n
        end
        res
      end

      def self.summary(res, action)
        verb = action == 'disable' ? 'Đã tắt' : 'Đã bật'
        msg = ["#{verb}: #{res[:changed].size} plugin."]
        msg << "Bỏ qua (đã ở trạng thái đó hoặc không tìm thấy): #{res[:skipped].size}." if res[:skipped].any?
        msg << "Lỗi: #{res[:errors].join('; ')}" if res[:errors].any?
        msg << 'Khởi động lại SketchUp để thay đổi có hiệu lực.' if res[:changed].any?
        msg.join("\n")
      end

      def self.save_set(name, names)
        name = name.to_s.strip[0, 40]
        return 'Hãy nhập tên cho bộ plugin.' if name.empty?
        valid = state['plugins'].map { |p| p['name'] }
        picked = Array(names).map(&:to_s).uniq & valid
        return 'Hãy tick ít nhất một plugin để lưu thành bộ.' if picked.empty?
        sets = load_sets
        sets[name] = picked
        save_sets(sets)
        "Đã lưu bộ \"#{name}\" gồm #{picked.size} plugin."
      rescue => e
        "Không lưu được bộ: #{e.message}"
      end

      def self.delete_set(name)
        sets = load_sets
        return 'Không tìm thấy bộ này.' unless sets.delete(name.to_s)
        save_sets(sets)
        "Đã xóa bộ \"#{name}\" (các plugin không bị ảnh hưởng)."
      rescue => e
        "Không xóa được bộ: #{e.message}"
      end

      def self.run
        dlg = UI::HtmlDialog.new(dialog_title: "VGD - Quản lý bật/tắt plugin #{PM::VERSION}",
                                 width: 640, height: 780,
                                 style: UI::HtmlDialog::STYLE_DIALOG)
        dlg.set_html(dialog_html)

        push = lambda do |msg|
          dlg.execute_script("render(#{state.to_json}, #{msg.to_s.to_json})")
        end

        dlg.add_action_callback('pm_ready') { |_c| push.call('') }

        dlg.add_action_callback('pm_change') do |_c, json|
          o = JSON.parse(json)
          action = o['action'] == 'enable' ? 'enable' : 'disable'
          if Array(o['names']).empty?
            push.call('Hãy tick ít nhất một plugin.')
          else
            push.call(summary(change(o['names'], action), action))
          end
        end

        dlg.add_action_callback('pm_save_set') do |_c, json|
          o = JSON.parse(json)
          push.call(save_set(o['name'], o['names']))
        end

        dlg.add_action_callback('pm_apply_set') do |_c, json|
          o = JSON.parse(json)
          action = o['action'] == 'enable' ? 'enable' : 'disable'
          names = load_sets[o['name'].to_s]
          if names.nil?
            push.call('Không tìm thấy bộ này.')
          else
            push.call(summary(change(names, action), action))
          end
        end

        dlg.add_action_callback('pm_delete_set') do |_c, json|
          o = JSON.parse(json)
          push.call(delete_set(o['name']))
        end

        dlg.show
      end

      def self.dialog_html
        <<-'HTML'
<!DOCTYPE html><html><head><meta charset="UTF-8">
<style>
body{font-family:Segoe UI,Arial,sans-serif;font-size:13px;margin:14px;color:#222}
h3{margin:0 0 8px} h4{margin:14px 0 6px}
.warn{background:#fff6e0;border:1px solid #e8c36a;border-radius:6px;padding:8px;margin-bottom:10px}
.bar{margin:8px 0}
input[type=text]{padding:6px;border:1px solid #bbb;border-radius:5px;width:220px}
.list{border:1px solid #ccc;border-radius:6px;max-height:300px;overflow:auto}
.row{display:flex;align-items:center;padding:4px 8px;border-bottom:1px solid #eee}
.row .nm{flex:1;margin-left:6px;word-break:break-all}
.badge{font-size:11px;padding:2px 8px;border-radius:10px;margin-right:8px;color:#fff}
.badge.on{background:#2e8b57}.badge.off{background:#888}.badge.conflict{background:#c0392b}
button{padding:6px 12px;margin:0 6px 4px 0;border:0;border-radius:5px;background:#2a6fdb;color:#fff;cursor:pointer}
button.alt{background:#777}button.offb{background:#c0762b}button.onb{background:#2e8b57}button.del{background:#b03a3a}
.set{display:flex;align-items:center;padding:4px 0;border-bottom:1px solid #eee}
.set .nm{flex:1}
#out{white-space:pre-wrap;margin-top:12px;padding:8px;background:#f3f3f3;border-radius:6px;display:none}
small{color:#666}
</style></head><body>
<h3 id="title">Quản lý bật/tắt plugin</h3>
<div class="warn">Thay đổi chỉ có hiệu lực sau khi khởi động lại SketchUp. Plugin bị tắt được cất vào một thư mục riêng, không bị xóa. Cẩn thận: tắt plugin mà plugin khác cần có thể gây lỗi khi mở lại.</div>
<div class="bar"><input type="text" id="q" placeholder="Tìm plugin..." oninput="draw()">
<button class="alt" onclick="selAll(true)">Chọn hết đang hiện</button>
<button class="alt" onclick="selAll(false)">Bỏ chọn hết</button></div>
<div class="list" id="list"></div>
<div class="bar"><button class="offb" onclick="act('disable')">Tắt mục đã chọn</button>
<button class="onb" onclick="act('enable')">Bật mục đã chọn</button></div>
<h4>Bộ plugin</h4>
<div class="bar"><input type="text" id="setname" placeholder="Tên bộ, ví dụ: Render">
<button onclick="saveSet()">Lưu mục đã chọn thành bộ</button></div>
<div id="sets"></div>
<small id="dir"></small>
<div id="out"></div>
<script>
var S={plugins:[],sets:[]}, checked={};
function el(t,c,x){var e=document.createElement(t);if(c)e.className=c;if(x!==undefined)e.textContent=x;return e}
function label(st){return st==='on'?'Đang bật':(st==='off'?'Đã tắt':'Trùng tên')}
function draw(){
  var q=document.getElementById('q').value.toLowerCase(), L=document.getElementById('list');
  L.innerHTML='';
  S.plugins.forEach(function(p){
    if(q && p.name.toLowerCase().indexOf(q)<0) return;
    var r=el('div','row'), cb=document.createElement('input');
    cb.type='checkbox'; cb.checked=!!checked[p.name];
    cb.onchange=function(){checked[p.name]=cb.checked};
    r.appendChild(cb); r.appendChild(el('span','nm',p.name));
    r.appendChild(el('span','badge '+p.status,label(p.status)));
    if(p.status!=='conflict'){
      var b=el('button',p.status==='on'?'offb':'onb',p.status==='on'?'Tắt':'Bật');
      b.onclick=function(){send('pm_change',{names:[p.name],action:p.status==='on'?'disable':'enable'})};
      r.appendChild(b);
    }
    L.appendChild(r);
  });
  var T=document.getElementById('sets'); T.innerHTML='';
  S.sets.forEach(function(s){
    var r=el('div','set');
    r.appendChild(el('span','nm',s.name+' ('+s.count+' plugin'+(s.missing?', '+s.missing+' không còn':'')+')'));
    var a=el('button','offb','Tắt bộ'); a.onclick=function(){send('pm_apply_set',{name:s.name,action:'disable'})};
    var b=el('button','onb','Bật bộ'); b.onclick=function(){send('pm_apply_set',{name:s.name,action:'enable'})};
    var c=el('button','del','Xóa bộ'); c.onclick=function(){send('pm_delete_set',{name:s.name})};
    r.appendChild(a); r.appendChild(b); r.appendChild(c); T.appendChild(r);
  });
}
function picked(){return Object.keys(checked).filter(function(k){return checked[k]})}
function selAll(v){
  var q=document.getElementById('q').value.toLowerCase();
  S.plugins.forEach(function(p){ if(!q||p.name.toLowerCase().indexOf(q)>=0) checked[p.name]=v });
  draw();
}
function send(cb,obj){sketchup[cb](JSON.stringify(obj))}
function act(a){send('pm_change',{names:picked(),action:a})}
function saveSet(){send('pm_save_set',{name:document.getElementById('setname').value,names:picked()})}
function render(s,msg){
  S=s; document.getElementById('title').textContent='Quản lý bật/tắt plugin - SketchUp '+s.year;
  document.getElementById('dir').textContent='Thư mục chứa plugin đã tắt: '+s.disabled_dir;
  draw();
  var o=document.getElementById('out');
  if(msg){o.style.display='block';o.textContent=msg}else{o.style.display='none'}
}
window.onload=function(){sketchup.pm_ready()};
</script></body></html>
        HTML
      end

      unless file_loaded?(__FILE__)
        UI.menu('Plugins').add_item('VGD: Quản lý bật/tắt plugin') { run }
        file_loaded(__FILE__)
      end
    end
  end
end
