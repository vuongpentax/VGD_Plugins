module Sketchup
  class SelectionObserver; end
  class Selection < Array
    attr_reader :observers
    def initialize; super; @observers = []; end
    def add_observer(observer); @observers << observer; end
    def remove_observer(observer); @observers.delete(observer); end
  end
end
module UI
  @timers = {}
  @timer_id = 0
  def self.start_timer(time, repeat, &block); @timer_id += 1; @timers[@timer_id] = block; @timer_id; end
  def self.stop_timer(id); @timers.delete(id); end
  class HtmlDialog
    STYLE_DIALOG = 0
    @@instances = []
    def self.instances; @@instances; end
    attr_reader :callbacks, :scripts
    def initialize(options); @callbacks={};@scripts=[];@visible=false;@@instances << self; end
    def set_file(path); end
    def add_action_callback(name, &block); @callbacks[name]=block; end
    def set_on_closed(&block); @on_closed=block; end
    def visible?; @visible; end
    def show; @visible=true; end
    def bring_to_front; @visible=true; end
    def close; @visible=false;@on_closed.call;@callbacks.clear; end
    def execute_script(script); @scripts << script; end
    def trigger(name, *args); @callbacks.fetch(name).call(nil,*args); end
  end
end
