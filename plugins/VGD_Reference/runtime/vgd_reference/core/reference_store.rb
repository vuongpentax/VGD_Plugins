module VGD
  module Reference
    class ReferenceStore
      attr_reader :items, :selected_id
      attr_accessor :hidden_all

      def initialize
        @items = []
        @selected_id = nil
        @hidden_all = false
        @next_id = 1
      end

      def next_id
        value = @next_id
        @next_id += 1
        "reference-#{value}"
      end

      def add(item)
        @items << item
        bring_to_front(item)
        item
      end

      def find(id)
        @items.find { |item| item.id == id.to_s }
      end

      def select(id)
        @selected_id = find(id)&.id
        @items.each { |item| item.selected = item.id == @selected_id }
        selected
      end

      def selected
        find(@selected_id)
      end

      def remove(id)
        item = find(id)
        return nil unless item
        @items.delete(item)
        if @selected_id == item.id
          @selected_id = nil
          item.selected = false
        end
        item
      end

      def bring_to_front(item)
        top = @items.map(&:z_index).max || 0
        item.z_index = top + 1
        @items.sort_by!(&:z_index)
      end

      def visible_items
        return [] if @hidden_all
        @items.select(&:visible).sort_by(&:z_index)
      end

      def hit_test_order
        visible_items.reverse
      end

      def to_a
        @items.sort_by(&:z_index)
      end

      def clear
        removed = @items.dup
        @items.clear
        @selected_id = nil
        @hidden_all = false
        removed
      end
    end
  end
end
