# frozen_string_literal: true
module VGD
  module Scenes
    module CameraControl
      def self.state(model)
        camera = model.active_view.camera
        page = model.pages.selected_page
        { eye_z_mm: camera.eye.z.to_f * 25.4, perspective: camera.perspective?,
          fov: camera.perspective? ? camera.fov : nil, fov_vertical: camera.perspective? ? camera.fov_is_height? : nil,
          height_mm: camera.perspective? ? nil : camera.height.to_f * 25.4,
          supported: !SceneTransfer.two_point?(camera), sig: camera_signature(camera),
          saved_sig: page && page.use_camera? ? camera_signature(page.camera) : nil }
      end

      def self.camera_signature(camera)
        [camera.eye, camera.target, camera.up].map { |v| v.to_a.map { |n| n.to_f.round(3) } }.flatten.join(',') +
          (camera.perspective? ? ":perspective:#{camera.fov_is_height?}:#{camera.fov.to_f.round(3)}" : ":parallel:#{camera.height.to_f.round(3)}")
      rescue StandardError
        nil
      end

      def self.preview(model, raw)
        raise ArgumentError, 'Thông số camera không hợp lệ.' unless raw.is_a?(Hash)
        raise 'Đóng edit Group/Component trước khi chỉnh camera.' if model.active_path
        original = model.active_view.camera
        raise 'Chưa hỗ trợ camera hai điểm / Match Photo.' if SceneTransfer.two_point?(original)
        camera = Scenes.camera_copy(original)
        if raw['kind'] == 'lens'
          if original.perspective?
            camera.fov = Scenes.number(raw['fov'], 1, 120, 'FOV (độ)')
          else
            camera.height = Scenes.number(raw['height_mm'], 0.001, 1e12, 'Chiều cao vùng nhìn (mm)') / 25.4
          end
        elsif raw['kind'] == 'align'
          mode = raw['axis_mode']
          raise ArgumentError, 'Hệ trục không hợp lệ.' unless %w[world local].include?(mode)
          axes = [Geom::Vector3d.new(1,0,0), Geom::Vector3d.new(0,1,0), Geom::Vector3d.new(0,0,1)]
          if mode == 'local'
            paths = if model.selection.empty?
                      page = model.pages.selected_page
                      page && SceneStore.owned?(page) ? SceneStore.metadata(page)['paths'] : nil
                    else
                      Geometry.selection_paths(model)
                    end
            raise 'Chọn đối tượng hoặc mở scene VGD có đối tượng nguồn để dùng trục đối tượng.' unless paths.is_a?(Array) && !paths.empty?
            transform = Geometry.resolve(model, paths.first)[1]
            axes = [transform.xaxis, transform.yaxis, transform.zaxis].map(&:normalize)
            raise 'Trục đối tượng suy biến hoặc bị shear.' if axes.any? { |v| v.length < 1e-9 } || axes.combination(2).any? { |a,b| a.dot(b).abs > 0.001 }
          end
          directions = axes.flat_map { |axis| [axis, axis.reverse] }
          code = raw['direction']
          current = original.target - original.eye
          raise 'Khoảng cách camera bằng 0.' if current.length < 1e-9
          direction = if code == 'AUTO'
                        directions.max_by { |v| v.dot(current.normalize) }
                      else
                        index = %w[+X -X +Y -Y +Z -Z].index(code)
                        raise ArgumentError, 'Hướng camera không hợp lệ.' unless index
                        directions[index]
                      end
          up = original.up
          up = axes[1] if direction.cross(up).length < 1e-6
          up = axes[0] if direction.cross(up).length < 1e-6
          up = direction.cross(up).normalize.cross(direction).normalize
          camera.set(original.target.offset(direction.reverse, current.length), original.target, up)
        else
          raise ArgumentError, 'Lệnh camera không hợp lệ.'
        end
        model.active_view.camera = camera
        model.active_view.invalidate
        { success: true, message: 'Đã xem trước camera. Bấm Update view để lưu góc nhìn mới.' }
      end

      def self.elevation(model, raw)
        raise ArgumentError, 'Thông số camera không hợp lệ.' unless raw.is_a?(Hash)
        raise 'Đóng edit Group/Component trước khi chỉnh camera.' if model.active_path
        original = model.active_view.camera
        raise 'Đổi sang Perspective hoặc Parallel Projection trước khi chỉnh cao độ. Chưa hỗ trợ hai điểm / Match Photo.' if SceneTransfer.two_point?(original)
        mode = raw['mode']
        raise ArgumentError, 'Chế độ cao độ không hợp lệ.' unless %w[absolute floor].include?(mode)
        z = if mode == 'absolute'
              Scenes.number(raw['z'], -1e9, 1e9, 'Cao độ mắt (mm)')
            else
              floor = Scenes.number(raw['floor'], -1e9, 1e9, 'Cao độ sàn (mm)')
              height = Scenes.number(raw['height'], 0, 1e6, 'Eye Height (mm)')
              Scenes.number(floor + height, -1e9, 1e9, 'Cao độ mắt (mm)')
            end
        raise ArgumentError, 'Chọn cách giữ hướng nhìn.' unless [true, false].include?(raw['keep_direction'])
        eye = original.eye.to_a; target = original.target.to_a
        delta = z / 25.4 - eye[2]
        eye[2] += delta
        target[2] += delta if raw['keep_direction']
        direction = Geom::Point3d.new(target) - Geom::Point3d.new(eye)
        raise ArgumentError, 'Cao độ làm hướng nhìn không hợp lệ. Bật Giữ hướng nhìn hoặc chọn cao độ khác.' if direction.length < 1e-9 || direction.normalize.cross(original.up.normalize).length < 1e-9
        camera = Sketchup::Camera.new(Geom::Point3d.new(eye), Geom::Point3d.new(target), original.up, original.perspective?)
        camera.aspect_ratio = original.aspect_ratio
        Scenes.copy_camera_lens(camera, original, model.active_view)
        model.active_view.camera = camera
        model.active_view.invalidate
        { success: true, message: "Đã xem trước cao độ mắt #{z.round(2)} mm theo Z thế giới. Bấm Cập nhật view để lưu vào scene." }
      end
    end
  end
end
