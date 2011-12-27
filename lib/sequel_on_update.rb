module Sequel
  module Plugins
    module OnUpdate
      # Plugin configuration
      def self.configure(model, opts={})
        model.on_update_options = opts
        model.on_update_options.freeze
      end

      module ClassMethods
        attr_reader :on_update_options
        # Propagate settings to the child classes
        # @param [Class] Child class
        def inherited(klass)
          super
          klass.on_update_options = self.on_update_options.dup
        end

        def on_update_options=(options)
          fields = options[:fields]
          if fields.nil? || !fields.is_a?(Array) || fields.empty?
            raise ArgumentError, ":fields must be a non-empty array"
          end
          options[:fields] = fields.uniq.compact
          hook = options[:hook]
          if hook 
            if !hook.is_a?(Symbol) and !hook.respond_to?(:call)
              raise ArgumentError, ":hook must be Symbol or callable"
            end
          else
            raise ArgumentError, "You must provide a hook to call"
          end
          
          field_hook_map = {}
          options[:fields].each do |f|
            field_hook_map[f.to_sym] = hook
          end
          @on_update_options ||= {}
          @on_update_options[:fields] ||= []
          @on_update_options[:hooks] ||= {}
          @on_update_options[:fields].concat(options[:fields])
          @on_update_options[:fields].uniq!
          @on_update_options[:fields].compact!
          @on_update_options[:hooks].merge!(field_hook_map)
        end
      end
      module InstanceMethods
        
        # Sets a slug column to the slugged value
        def before_update
          super
          @columns_to_be_changed = changed_columns.dup
        end
         
        def after_update
          collect_hooks.each do |hook|
            if hook.respond_to?(:call)
              hook.call(@columns_to_be_changed)
            else
              self.send(hook, @columns_to_be_changed)
            end
          end
          super
        end
        
        def collect_hooks
          hooks = []
          self.class.on_update_options[:fields].each do |field|
            if @columns_to_be_changed.include?(field)
              hooks << self.class.on_update_options[:hooks][field.to_sym]
            end
          end
          hooks.uniq!
          hooks.compact!
          hooks
        end
      end # InstanceMethods
    end # OnUpdate
  end # Plugins
end # Sequel