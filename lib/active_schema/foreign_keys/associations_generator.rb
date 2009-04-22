module ActiveSchema
  module ForeignKeys
    class AssociationsGenerator < CodeGenerator
      
      def module_name
        'GeneratedAssociations'
      end
      
      def examine(model)
        discover_foreign_key_associations(model)
        discover_reverse_foreign_key_associations(model)        
      end
      
      def record_association(model, association_kind, association_id, options)
        code = "#{association_kind.to_s} :#{association_id.to_s}, #{options.inspect} unless method_defined?(:#{association_id.to_s})"
        record_declaration model, association_id, code 
      end
      
      def discover_foreign_key_associations(model)
        model.foreign_keys.each do |foreign_key|
          next unless foreign_key.column_names.size == 1
          column_name = foreign_key.column_names.first
          next unless column_name =~ /^(.*)_id$/
          columns = model.columns_hash
          column = columns[column_name]
          association_id = $1.to_sym
          references_class_name = foreign_key.references_table_name.classify
          references_class = model.send :compute_type, references_class_name
          # belongs_to
          record_association model, :belongs_to, association_id, { :class_name => references_class_name, :foreign_key => column_name }
          # has_one/has_many
          association_id = model.name.demodulize.underscore
          association_id = $1 if association_id =~ /^#{references_class_name.underscore.singularize}_(.*)$/
          options = { :class_name => model.name, :foreign_key => column_name }
          if column.unique? && column.unique_scope.empty?
            record_association references_class, :has_one, association_id, options
          else
            options[:order] = :position if columns.has_key?('position')
            association_id = association_id.pluralize.to_sym
            record_association references_class, :has_many, association_id, options
          end
        end
      end
      
      def discover_reverse_foreign_key_associations(model)
        model.reverse_foreign_keys.each do | foreign_key |
          next unless foreign_key.column_names.size == 1
          column_name = foreign_key.column_names.first
          next unless column_name =~ /^(.*)_id$/
          begin
            referencing_class = model.send :compute_type, foreign_key.table_name.classify
          rescue NameError
            case foreign_key.table_name
              when /^#{model.table_name}_(.*)$/, /^(.*)_#{model.table_name}$/
              referencing_table_name = $1
              referencing_class_name = referencing_table_name.classify
              referencing_class = model.send :compute_type, referencing_class_name
              association_id = referencing_class.name.demodulize.underscore
              association_id = $1 if association_id =~ /^#{model.name.underscore.singularize}_(.*)$/
              association_id = association_id.pluralize.to_sym
              record_association model, :has_and_belongs_to_many, association_id, {:class_name => referencing_class.name, :join_table => foreign_key.table_name}
            else
              puts "Could not find model for table: #{foreign_key.table_name}"
            end
          end
        end
      end
    end
    
  end
end
