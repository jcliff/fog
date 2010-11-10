module Fog
  class Service

    class Error < Fog::Errors::Error; end
    class NotFound < Fog::Errors::NotFound; end

    module Collections

      def collections
        service.collections
      end

      def requests
        service.requests
      end

    end

    class << self

      def inherited(child)
        child.class_eval <<-EOS, __FILE__, __LINE__
          module Collections
            include Fog::Service::Collections

            def service
              #{child}
            end
          end

          def self.service
            #{child}
          end
        EOS
      end

      def new(options={})
        if Fog.bin
          default_credentials = Fog.credentials.reject {|key, value| !requirements.include?(key)}
          options = default_credentials.merge(options)
        end

        validate_arguments options, \
          :required => requirements, 
          :optional => recognized
          
        setup_requirements

        if Fog.mocking?
          service::Mock.send(:include, service::Collections)
          service::Mock.new(options)
        else
          service::Real.send(:include, service::Collections)
          service::Real.new(options)
        end
      end

      def setup_requirements
        if superclass.respond_to?(:setup_requirements)
          superclass.setup_requirements
        end

        @required ||= false
        unless @required
          for collection in collections
            require [@model_path, collection].join('/')
            constant = collection.to_s.split('_').map {|characters| characters[0...1].upcase << characters[1..-1]}.join('')
            service::Collections.module_eval <<-EOS, __FILE__, __LINE__
              def #{collection}(attributes = {})
                #{service}::#{constant}.new({:connection => self}.merge(attributes))
              end
            EOS
          end
          for model in models
            require [@model_path, model].join('/')
          end
          for request in requests
            require [@request_path, request].join('/')
          end
          @required = true
        end
      end

      def model_path(new_path)
        @model_path = new_path
      end

      def collection(new_collection)
        collections << new_collection
      end

      def collections
        @collections ||= []
      end

      def model(new_model)
        models << new_model
      end

      def models
        @models ||= []
      end

      def request_path(new_path)
        @request_path = new_path
      end

      def request(new_request)
        requests << new_request
      end

      def requests
        @requests ||= []
      end

      def requires(*args)
        requirements.concat(args)
      end

      def requirements
        @requirements ||= []
      end

      def recognizes(*args)
        recognized.concat(args)
      end

      def recognized
        @recognized ||= []
      end

      def reset_data(keys=Mock.data.keys)
        Mock.reset_data(keys)
      end

      def validate_arguments(opts, spec = {})
        spec[:required] ||= []
        spec[:optional] ||= []

        sorter  = lambda{ |x, y| x.to_s <=> y.to_s }
        allowed = (spec[:optional] + spec[:required]).sort &sorter
        keys    = opts.keys.map{ |k| k.to_sym }

        keys.sort! &sorter
        spec[:required].sort! &sorter

        unless spec[:required].empty? 
          k = spec[:required] & keys
          raise ArgumentError, "Missing required arguments: #{(spec[:required] - k).join(', ')}" \
            unless k == spec[:required]
        end

        k = keys - allowed    
        raise ArgumentError, "Unrecognized arguments: #{k.join(', ')}" \
          unless k.empty?
      end

    end

  end
end

