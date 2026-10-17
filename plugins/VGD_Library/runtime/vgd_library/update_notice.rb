# encoding: UTF-8
# Version comparison shared by VGD SketchUp extensions.
#
# Plugins no longer check for updates themselves when SketchUp starts: that popup
# interrupted users at every launch. VGD Center is the only place that reports and
# installs updates, when the user opens it.
module VGD
  module UpdateNotice
    extend self

    # Kept so existing plugin loaders can still call it; intentionally does nothing.
    def start(_product_id, _product_name, _current_version)
      nil
    end

    def version_key(value)
      core, pre = value.to_s.split('-', 2)
      numbers = core.to_s.split('.').map { |part| Integer(part) rescue 0 }
      [numbers, pre]
    end

    def newer?(remote, current)
      remote_core, remote_pre = version_key(remote)
      current_core, current_pre = version_key(current)
      length = [remote_core.length, current_core.length].max
      (0...length).each do |index|
        comparison = (remote_core[index] || 0) <=> (current_core[index] || 0)
        return comparison > 0 unless comparison == 0
      end
      return false if current_pre.nil?
      return true if remote_pre.nil?
      remote_parts = remote_pre.split(/[.-]/)
      current_parts = current_pre.split(/[.-]/)
      [remote_parts.length, current_parts.length].max.times do |index|
        left = remote_parts[index]
        right = current_parts[index]
        return false if left.nil?
        return true if right.nil?
        comparison = if left.match?(/\A\d+\z/) && right.match?(/\A\d+\z/)
          left.to_i <=> right.to_i
        elsif left.match?(/\A\d+\z/)
          -1
        elsif right.match?(/\A\d+\z/)
          1
        else
          left <=> right
        end
        return comparison > 0 unless comparison == 0
      end
      false
    end
  end
end
