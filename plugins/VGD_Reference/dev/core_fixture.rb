module VGD
  module Reference
    first = ReferenceItem.new(id: 'one', source_type: :file, source_path: 'one.png', image_width: 1200, image_height: 800, x: 20, y: 30, width: 300, height: 200, z_index: 1)
    second = ReferenceItem.new(id: 'two', source_type: :file, source_path: 'two.png', image_width: 800, image_height: 1200, x: 50, y: 60, width: 120, height: 180, z_index: 2)
    raise 'References should start locked and passive.' unless first.locked && second.locked

    cursor_x, cursor_y = 140.0, 100.0
    before_uv = first.screen_uv(cursor_x, cursor_y)
    first.zoom_at(cursor_x, cursor_y, 0.5)
    after_uv = first.screen_uv(cursor_x, cursor_y)
    raise 'Cursor-centered zoom moved the image point under the cursor.' unless (before_uv[0] - after_uv[0]).abs < 0.000001 && (before_uv[1] - after_uv[1]).abs < 0.000001
    raise 'Zoom changed the screen frame.' unless first.width == 300.0 && first.height == 200.0

    old_x, old_y = first.x, first.y
    old_uv = [first.view_u0, first.view_v0]
    first.pan_content(18, -12)
    raise 'Image content pan moved the frame.' unless first.x == old_x && first.y == old_y
    raise 'Image content pan did not update view UV.' unless old_uv != [first.view_u0, first.view_v0]

    first.crop_u0 = 0.1
    first.crop_v0 = 0.2
    first.crop_u1 = 0.9
    first.crop_v1 = 0.8
    first.zoom_at(cursor_x, cursor_y, 0.5)
    first.reset_zoom
    raise 'Reset zoom did not fit the crop.' unless [first.view_u0, first.view_v0, first.view_u1, first.view_v1] == [0.1, 0.2, 0.9, 0.8]

    store = ReferenceStore.new
    store.add(first)
    store.add(second)
    raise 'Topmost hit order is wrong.' unless store.hit_test_order.map(&:id) == ['two', 'one']
    store.select('one')
    raise 'Store selection did not update item state.' unless store.selected.equal?(first) && first.selected && !second.selected

    crop = CropController.new(first)
    crop.drag(HitTester::CROP_LEFT, first.x + first.width * 0.2, first.y + first.height / 2.0)
    crop.commit
    crop_aspect = (first.image_width * first.crop_width) / (first.image_height * first.crop_height)
    raise 'Crop did not refit the frame to the cropped image.' unless (first.width / first.height - crop_aspect).abs < 0.000001
    raise 'Crop did not reset the view UV.' unless [first.view_u0, first.view_v0, first.view_u1, first.view_v1] == [first.crop_u0, first.crop_v0, first.crop_u1, first.crop_v1]

    puts 'PASS: reference store, z-order, selection, anchored zoom, content pan, crop fit, and reset zoom.'
  end
end
