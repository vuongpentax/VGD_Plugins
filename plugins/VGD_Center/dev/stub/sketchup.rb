# Stub tối thiểu thay cho SketchUp khi chạy test ngoài SketchUp (chỉ đủ cho test_center.rb).
def file_loaded?(_file) false end
def file_loaded(_file) end
MB_YESNO = 4
IDYES = 6
IDNO = 7

$stub_messages = []
$stub_answer = IDYES
$stub_installs = []
$stub_plugins_dir = nil

module Sketchup
  def self.version; '24.0.553'; end
  def self.read_default(_section, _key, default = nil); default; end
  def self.write_default(*_args); end
  def self.extensions; {}; end
  def self.find_support_file(_name); $stub_plugins_dir; end
  def self.install_from_archive(path, _overwrite); $stub_installs << path; true; end
end

module UI
  class Menu
    def add_item(_command); end
  end
  class Command
    attr_accessor :tooltip, :status_bar_text, :small_icon, :large_icon
    def initialize(_title, &_block); end
  end
  class Toolbar
    def initialize(_name); end
    def add_item(_command); end
    def restore; end
  end
  def self.menu(_name); Menu.new; end
  def self.start_timer(_seconds, _repeat); end
  def self.messagebox(message, _type = 0); $stub_messages << message; $stub_answer; end
end
