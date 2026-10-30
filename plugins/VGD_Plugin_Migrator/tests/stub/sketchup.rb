# Stub tối thiểu thay cho sketchup.rb khi chạy thử ngoài SketchUp
def file_loaded?(_f) false end
def file_loaded(_f) end

module Sketchup
  def self.version; '24.0.553'; end
end

module UI
  class Menu
    def add_item(_name, &_blk); end
  end
  def self.menu(_n); Menu.new; end
  MB_YESNO = 4
  IDYES = 6
end
MB_YESNO = 4
IDYES = 6
