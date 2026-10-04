require 'json'
require 'fileutils'
require 'ostruct'
require 'base64'
require 'tmpdir'
require 'securerandom'
require 'open3'
$loaded = []
def file_loaded?(path); $loaded.include?(path); end
def file_loaded(path); $loaded << path; end
class Numeric
  def degrees; self * Math::PI / 180; end
end
ORIGIN = [0, 0, 0]
X_AXIS = [1, 0, 0]
module Geom
  class Transformation
    attr_reader :kind, :value
    def initialize(kind, value); @kind, @value = kind, value; end
    def self.translation(value); new(:translation, value); end
    def self.rotation(origin, axis, angle); new(:rotation, [origin, axis, angle]); end
  end
end
class SketchupExtension
  attr_accessor :description, :version, :creator, :copyright
  def initialize(*args); end
end
module Sketchup
  def self.platform; :platform_win; end
  def self.active_model; @model ||= Model.new; end
  def self.register_extension(*args); end
  def self.read_default(section, key, fallback); (@settings ||= {}).fetch([section,key],fallback); end
  def self.write_default(section, key, value); (@settings ||= {})[[section,key]]=value; end
  class ImageRep
    # Match SketchUp's real contract: nil for successful reads; bad data raises.
    def load_file(path); @path = path; raise ArgumentError, 'Invalid image' if path.include?('corrupt'); nil; end
    def width; 1000; end
    def height; 500; end
  end
end
module VGD_ImageImporter
  module FilePicker
    def self.choose(directory, extensions); (@selected || []).dup; end
    def self.selected=(paths); @selected=paths; end
  end
end
module UI
  class Command
    attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon
    def initialize(*args, &block); end
  end
  class Toolbar
    def initialize(*args); end
    def add_item(*args); end
    def restore; end
  end
  class Menu
    def add_submenu(*args); self; end
    def add_item(*args); end
  end
  def self.menu(*args); Menu.new; end
  def self.select_directory(**args); @directory; end
  def self.directory=(value); @directory=value; end
  def self.openpanel(*args); (@selected ||= []).shift; end
  def self.selected=(value); @selected=value; end
  class HtmlDialog
    STYLE_DIALOG = 0
    attr_reader :callbacks, :scripts
    def initialize(**args); @callbacks={}; @scripts=[]; end
    def set_file(path); end
    def add_action_callback(name, &block); @callbacks[name]=block; end
    def set_on_closed(&block); @on_closed=block; end
    def execute_script(script); @scripts << script; end
    def visible?; @visible; end
    def show; @visible=true; end
    def bring_to_front; @focused=true; end
    def close; @visible=false; @on_closed.call; end
  end
end
class Entities
  attr_reader :instances, :transforms
  def initialize; @instances=[]; @transforms=[]; end
  def add_image(path, origin, width); path.include?('noimage') ? nil : OpenStruct.new; end
  def transform_entities(transform, items); @transforms << transform; end
  def add_instance(definition, transform); instance=OpenStruct.new(definition:definition, transform:transform); @instances << instance; instance; end
end
class Definitions < Array
  def add(name); definition=OpenStruct.new(name:name, entities:Entities.new, behavior:OpenStruct.new); def definition.set_attribute(*args); end; self << definition; definition; end
  def remove(definition); delete(definition); end
end
class Material
  attr_reader :name, :texture
  def initialize(name); @name=name; end
  def texture=(path); raise 'bad texture' if path.include?('badtexture'); @texture=OpenStruct.new(size:nil, path:path); end
end
class Materials < Array
  def add(name); name += '1' while any? { |material| material.name == name }; material=Material.new(name); self << material; material; end
  def remove(material); delete(material); end
end
class Model
  attr_reader :definitions, :materials, :active_entities, :operations
  def initialize; @definitions=Definitions.new; @materials=Materials.new; @active_entities=Entities.new; @operations=[]; end
  def start_operation(*args); @operations << :start; end
  def commit_operation; @operations << :commit; end
  def abort_operation; @operations << :abort; end
end
