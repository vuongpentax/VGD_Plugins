module VGD
  module Transform
    # Hàng đợi kéo trực tiếp: giao diện gửi giá trị rất nhanh, nhưng chỉ giá trị mới nhất mới cần áp dụng vào model.
    # Nhận giá trị chỉ là việc nhẹ (không đụng model), việc nặng làm theo nhịp hẹn giờ nên không bị dồn hàng đợi.
    class LiveQueue
      def initialize
        clear
      end

      # Nhận giá trị mới (giá trị cũ chưa xử lý bị bỏ). Trả true nếu người gọi cần hẹn giờ xử lý (chưa có nhịp nào đang chờ).
      def push(payload)
        @pending = payload
        return false if @scheduled
        @scheduled = true
      end

      # Lấy giá trị mới nhất để xử lý (nil nếu không có). Sau khi lấy, giá trị kế tiếp lại cần hẹn giờ.
      def take
        payload = @pending
        @pending = nil
        @scheduled = false
        payload
      end

      def pending?
        !@pending.nil?
      end

      def clear
        @pending = nil
        @scheduled = false
      end
    end
  end
end
