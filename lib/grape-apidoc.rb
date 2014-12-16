require 'grape-apidoc/version'

module Grape
  class API
    class << self
    
      def add_api_documentation
        
        @@combined_routes = {}
          routes.each do |route|
            route_match = route.route_path.split(/^.*?#{route.route_prefix.to_s}/).last.match('\/([\w|-]*?)[\.\/\(]')
            next if route_match.nil?
            resource = route_match.captures.first
            next if resource.empty?
            resource.downcase!
            @@combined_routes[resource] ||= []
            _route_hidden = route.route_hidden
            next if _route_hidden.present?
            @@combined_routes[resource] << route
          end

        @@combined_namespaces = {}
        combine_namespaces(self)
        documentation = create_documentation
        documentation.setup
        mount(documentation)
      end

      private

      def combine_namespaces(app)
        app.endpoints.each do |endpoint|
          ns = if endpoint.respond_to?(:namespace_stackable)
                 endpoint.namespace_stackable(:namespace).last
               else
                 endpoint.settings.stack.last[:namespace]
               end
          @@combined_namespaces[ns.space] = ns if ns

          combine_namespaces(endpoint.options[:app]) if endpoint.options[:app]
        end
      end

      def create_documentation

        Class.new(Grape::API) do

          def self.setup
            @@mount_path = '/apidoc'
            get @@mount_path do
              header['Access-Control-Allow-Origin']   = '*'
              header['Access-Control-Request-Method'] = '*'
              
              combined_apidoc_json = {
                name: 'Agents',
                apiVersion: '2',
                baseUrl: '/api/v2',
                resources: create_apis
              }
              
              combined_apidoc_json
            end
            
          end


          helpers do
            
            def create_apis
            
              resources = []
              routes = @@combined_routes
              namespaces = @@combined_namespaces
              
              routes.each do |path, op_routes|
                @description = nil
                
                next if routes[path].all?(&:route_hidden)
                
                apis = op_routes.map do |route|
            
                  operation = {
                    path: route.route_path.gsub('(.:format)', '.json'),
                    method: route.route_method,
                    description: route.route_description || '',
                    headers: route.route_headers || [] ,
                    params: parse_params(route.route_params, route.route_path, route.route_method),
                    responseStatuses: parse_http_codes(route.route_http_codes),
                    errors: route.route_errors || []
                  }
            
                end.compact
            
                namespaces.each do |key, val|
                  if val.space === path && !val.options.empty?
                     @description = val.options[:desc]
                  else
                     next
                  end
                end
            
                description = @description || "Operations about #{path}"
            
                resources << {
                  name: path,
                  description: description,
                  apis: apis
                }
              end
            
              resources
            end
            
            def parse_params(params, path, method)
              params ||= []
            
              non_nested_parent_params = params.reject do |param, _|
                is_nested_param = /^#{ Regexp.quote param }\[.+\]$/
                params.keys.any? { |p| p.match is_nested_param }
              end
            
              non_nested_parent_params.map do |param, value|
                # value[:type] = 'File' if value.is_a?(Hash) && ['Rack::Multipart::UploadedFile', 'Hash'].include?(value[:type])
                items = {}
            
                raw_data_type = value.is_a?(Hash) ? (value[:type] || 'string').to_s : 'string'
                data_type     = case raw_data_type
                                when 'Virtus::Attribute::Boolean'
                                  'Boolean'
                                when 'Date', 'Integer', 'String', 'File'
                                  raw_data_type
                                when 'BigDecimal'
                                  'long'
                                when 'DateTime'
                                  'dateTime'
                                when 'Numeric'
                                  'double'
                                when 'Hash'
                                  'Enum'
                                end
                description   = value.is_a?(Hash) ? value[:desc] || value[:description] : ''
                required      = value.is_a?(Hash) ? !!value[:required] : false
                _example_value = value.is_a?(Hash) ? value[:documentation] : nil
                example_value = _example_value[:example] if _example_value.present?
                enum_values   = value.is_a?(Hash) ? value[:values] : nil
                enum_values   = enum_values.call if enum_values && enum_values.is_a?(Proc)
            
                name          = (value.is_a?(Hash) && value[:full_name]) || param
            
                parsed_params = {
                  name:          name,
                  description:   description,
                  type:          data_type,
                  required:      required,
                }
                parsed_params.merge!(items: items) if items.present?
                parsed_params.merge!(example: example_value) if example_value
                parsed_params.merge!(options: enum_values) if enum_values
                parsed_params
              end
            end
            
            def parse_http_codes(codes)
              codes ||= {}
              codes.map do |k, v|
                http_code_hash = {
                  code: k,
                  message: v
                }
                http_code_hash
              end
            end
          end
        end
      end
    end
  end
end
