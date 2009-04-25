module ActiveSchema
  module Constraints
    class ValidationsGenerator < CodeGenerator

      def module_name
        'GeneratedValidations'
      end
      
      def examine(model)
        discover_column_validations(model)
        discover_association_validations(model)
      end
      
      def record_validation(model, validation, column_name, options)
        code = "#{validation} :#{column_name.to_s}, #{options.inspect}"
        declaration_id = "#{validation}-#{column_name}"
        record_declaration model, declaration_id, code
      end
      
      def should_validate? column
        column.name !~ /^(((created|updated)_(at|on))|position)$/
      end
      
      def discover_column_validations(model)
        model.content_columns.each do |column|
          next unless should_validate? column
          name = column.name.to_sym
          # Data-type validation
          if column.type == :integer
            record_validation model, :validates_numericality_of, name, {:allow_nil => true, :only_integer => true}
          elsif column.number?
            record_validation model, :validates_numericality_of, name, {:allow_nil => true}
          elsif column.text? && column.limit
            record_validation model, :validates_length_of, name, {:allow_nil => true, :maximum => column.limit}
          elsif column.type == :enum
            # Support MySQL ENUM type as provided by the enum_column plugin
            record_validation model, :validates_inclusion_of, name, :in => column.limit 
          end
          
          # NOT NULL constraints
          if column.required_on
            # Work-around for a "feature" of the way validates_presence_of handles boolean fields
            # See http://dev.rubyonrails.org/ticket/5090 and http://dev.rubyonrails.org/ticket/3334
            if column.type == :boolean
              options = {:on => column.required_on, :in => [true, false] }
              options[:message] = I18n.translate('activerecord.errors.messages.blank') # FIXME: Get message runtime
              record_validation model, :validates_inclusion_of, name, options  
            else
              record_validation model, :validates_presence_of, name, {:on => column.required_on}
            end
          end
          
          # UNIQUE constraints
          if column.unique?
            record_validation model, :validates_uniqueness_of, name, {:scope => column.unique_scope.map(&:to_sym), :allow_nil => true, :case_sensitive => column.case_sensitive?}
          end
        end
        
      end
      
      def discover_association_validations(model)
        columns = model.columns_hash
        model.reflect_on_all_associations(:belongs_to).each do |association|
          column = columns[association.primary_key_name]
          unless column
            puts "FAILED: invalid association #{association.primary_key_name} on #{model}"
            next
          end
          next unless should_validate? column
          # NOT NULL constraints
          if column.required_on
            declaration_id = "presence_of_#{column.name}"
            record_declaration model, declaration_id, "validates_presence_of :#{column.name}, :on => :#{column.required_on}, :if => lambda { |record| record.#{association.name}.nil? }"
          end
          # UNIQUE constraints
          if column.unique?
            record_validation model, :validates_uniqueness_of, column.name, {:scope => column.unique_scope.map(&:to_sym), :allow_nil => true}
          end
        end
      end
      
    end
  end
end