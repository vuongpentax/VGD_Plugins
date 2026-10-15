module VGD
  module Reference
    class AppObserver < Sketchup::AppObserver
      def expectsStartupModelNotifications
        true
      end

      def onNewModel(model)
        Session.setup_for_model(model, reset: true)
      end

      def onOpenModel(model)
        Session.setup_for_model(model, reset: true)
      end

      def onActivateModel(model)
        Session.setup_for_model(model)
      end

      def onQuit
        Session.shutdown
      end
    end
  end
end
