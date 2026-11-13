# encoding: UTF-8
module VGD
  module Dim
    module Animation
      def self.providers(model)
        page=model.options['PageOptions']; slide=model.options['SlideshowOptions']
        raise 'SketchUp không có PageOptions/SlideshowOptions.' unless page && slide
        [page,slide]
      end
      def self.read(model)
        page,slide=providers(model)
        {'enabled'=>!!page['ShowTransition'],'transition'=>page['TransitionTime'],
         'delay'=>slide['SlideTime'],'loop'=>!!slide['LoopSlideshow']}
      end
      def self.write(model,settings)
        raise ArgumentError, 'Animation không hợp lệ.' unless settings.is_a?(Hash)
        %w[enabled loop].each { |key| raise ArgumentError, 'Animation phải là bật/tắt.' unless [true,false].include?(settings[key]) }
        values={}
        %w[transition delay].each do |key|
          number=Float(settings[key]) rescue nil
          raise ArgumentError, 'Thời gian phải là số giây không âm.' unless number && number.finite? && number>=0
          values[key]=number
        end
        page,slide=providers(model)
        before=read(model)
        begin
          page['ShowTransition']=settings['enabled']; page['TransitionTime']=values['transition']
          slide['SlideTime']=values['delay']; slide['LoopSlideshow']=settings['loop']
        rescue StandardError
          page['ShowTransition']=before['enabled']; page['TransitionTime']=before['transition']
          slide['SlideTime']=before['delay']; slide['LoopSlideshow']=before['loop']
          raise
        end
        read(model)
      end
    end
  end
end
