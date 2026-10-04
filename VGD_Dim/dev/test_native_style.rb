# Simulation only. Actual Win32 dispatch/font rendering require native SketchUp.
class FakeStyleAdapter
  attr_reader :events
  attr_accessor :missing, :fail_page
  def initialize; @events=[]; end
  def check_platform!; @events << [:platform]; end
  def find(page); @events << [:find,page]; page != missing; end
  def click(page)
    raise 'Native click failed' if page == fail_page
    @events << [:click,page,Sketchup.active_model.selection.to_a]
  end
end

def run_native_style_tests
  native = VGD::Dim::NativeStyle
  build = lambda do
    m=Sketchup::FakeModel.new; Sketchup.active_model=m
    d=Sketchup::DimensionLinear.new; t=Sketchup::Text.new; outside=Sketchup::DimensionLinear.new
    edge=Sketchup::Edge.new([])
    [d,t,outside,edge].each { |e| m.entities << e }
    m.selection.add([d,t,edge])
    api=FakeStyleAdapter.new; native.adapter=api
    UI.info_result=true; UI.info_pages=[]
    [m,d,t,outside,edge,api]
  end
  m,d,t,outside,edge,api=build.call
  errors=[]; native.apply(m,{}) { |error| errors << error }
  begin
    native.apply(m,{})
    raise 'Duplicate apply accepted'
  rescue ArgumentError
    raise 'Duplicate cleared active job' unless native.running?
  end
  raise 'Plugin mutation before native update' unless m.operations==0
  UI.drain
  clicks=api.events.select { |event| event[0]==:click }
  raise 'Wrong native subsets' unless clicks==[[:click,'Dimensions',[d]],[:click,'Text',[t]]]
  first_click=api.events.index(clicks.first)
  raise 'Both controls not checked first' unless api.events[0...first_click].include?([:find,'Text'])
  raise 'Selected tags missing' unless d.layer=='000 DIM' && t.layer=='000 TEXT'
  raise 'Unselected/geometry mutated' unless outside.layer.nil? && edge.layer.nil?
  raise 'Selection not restored' unless m.selection.to_a==[d,t,edge]
  raise 'Completion/state wrong' unless errors==[nil] && !native.running? && m.commits==1

  m,d,t,outside,edge,api=build.call; api.missing='Text'; errors=[]
  native.apply(m,{}) { |e| errors << e }; UI.drain
  raise 'Missing second control still clicked first' if api.events.any? { |e| e[0]==:click }
  raise 'Timeout mutated model' unless m.operations==0 && m.selection.to_a==[d,t,edge] && errors.first

  m,d,t,outside,edge,api=build.call; UI.info_result=false; errors=[]
  native.apply(m,{}) { |e| errors << e }
  raise 'Synchronous failure leaked selection/job' unless errors.first && !native.running? && m.selection.to_a==[d,t,edge]

  m,d,t,outside,edge,api=build.call; errors=[]
  native.apply(m,{}) { |e| errors << e }
  m.selection.clear; m.selection.add(outside); UI.drain
  raise 'User selection overwritten' unless m.selection.to_a==[outside] && m.operations==0 && errors.first

  m,d,t,outside,edge,api=build.call; errors=[]
  native.apply(m,{}) { |e| errors << e }
  Sketchup.active_model=Sketchup::FakeModel.new; UI.drain
  raise 'Switched model edited' unless m.operations==0 && errors.first && !native.running?

  m,d,t,outside,edge,api=build.call; api.fail_page='Text'; errors=[]
  native.apply(m,{}) { |e| errors << e }; UI.drain
  raise 'Partial native updates misreported' unless errors.first.message.include?('Đã gọi cập nhật native Dimensions') && m.operations==0
  raise 'Partial failure selection lost' unless m.selection.to_a==[d,t,edge]

  m,d,t,outside,edge,api=build.call; errors=[]
  native.apply(m,{}) { |e| errors << e }; native.cancel; UI.drain
  raise 'Cancel leaked timer/job' unless errors.first && !native.running? && UI.timers.empty? && m.selection.to_a==[d,t,edge] && m.operations==0

  m,d,t,outside,edge,api=build.call
  api.define_singleton_method(:check_platform!) { raise 'Unsupported platform' }
  begin
    native.apply(m,{})
    raise 'Unsupported platform accepted'
  rescue RuntimeError => e
    raise unless e.message=='Unsupported platform'
  end
  raise 'Platform guard changed selection/job' unless m.selection.to_a==[d,t,edge] && m.operations==0 && !native.running?

  # Adapter must match visible enabled native buttons in THIS process only.
  fake_api=Object.new
  items={
    1=>{handle:1,pid:Process.pid,text:'Model Info',class:'#32770',valid:true,visible:true,enabled:true},
    2=>{handle:2,pid:Process.pid+1,text:'Model Info',class:'#32770',valid:true,visible:true,enabled:true},
    3=>{handle:3,pid:Process.pid,text:'Update selected text',class:'Button',valid:true,visible:true,enabled:true},
    4=>{handle:4,pid:Process.pid,text:'Update selected text',class:'Button',valid:true,visible:false,enabled:true},
    5=>{handle:5,pid:Process.pid,text:'Update selected dimensions',class:'Button',valid:true,visible:true,enabled:false}
  }
  fake_api.define_singleton_method(:enumerate) { |parent=nil| parent ? [3,4,5] : [1,2] }
  fake_api.define_singleton_method(:descriptor) { |handle| items.fetch(handle) }
  fake_api.define_singleton_method(:click) { |*pair| @clicked=pair }
  adapter=native::WindowsAdapter.new(fake_api)
  raise 'Foreign/hidden/disabled button matched' unless adapter.find('Text')==[1,3] && adapter.find('Dimensions').nil?
  adapter.click('Text'); raise 'Wrong Win32 target' unless fake_api.instance_variable_get(:@clicked)==[1,3]
  items[4][:visible]=true
  begin
    adapter.find('Text'); raise 'Duplicate allowed'
  rescue RuntimeError => e
    raise unless e.message.include?('Có nhiều nút')
  end
  puts 'PASS: Model Info bridge preflight/subsets/selection restore, timeout/cancel/model change/partial failure, duplicate apply guard, Win32 target filtering (simulation)'
end
