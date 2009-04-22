module ActiveSchema
  class CodeGenerator
    
    def initialize
      @declarations = {}
    end
    
    def code_path
      "#{RAILS_ROOT}/lib/#{module_name.underscore}.rb"
    end

    def regenerate
      puts "Loading models..."
      load_models ["#{RAILS_ROOT}/app/models/"]
      models = ::ActiveRecord::Base.send(:subclasses)
      puts "#{models.size} ActiveRecord subclasses:\n  #{models.map(&:name).sort.to_sentence}"
      models = models.collect { |model| is_sti?(model) ? model.base_class : model }
      puts "#{models.size} base class models:\n  #{models.map(&:name).sort.to_sentence}"
      models = models.find_all { |model| model.table_exists? }
      puts "#{models.size} models with tables:\n  #{models.map(&:name).sort.to_sentence}"
      models = models.reject { |model| model.abstract_class? }
      puts "#{models.size} non-abstract class models:\n  #{models.map(&:name).sort.to_sentence}"
      models.each do |model|
        puts "Examining #{model.name}"
        examine(model)
      end
      code = "module #{module_name}\n\n"
      @declarations.each_pair do |model,associations|
        code << "  #{model.name}.class_eval do \n" 
        associations.each_pair do |association_id,declaration| 
          code << "    #{declaration}\n"
        end
        code << "  end\n\n"
      end
      code << "end\n"
      File.new(code_path, 'w+').write(code)
      puts "Generated #{@declarations.sum(&:size)} declarations for #{@declarations.size} classes in #{code_path}"
    end

    def is_sti? model
      model.inheritance_column.present? and model.columns.include? model.inheritance_column
    rescue
      false
    end

    # Make sure all models are loaded - without reloading any that
    # ActiveRecord::Base is already aware of (otherwise we start to hit some
    # messy dependencies issues).
    def load_models(dirs)
      dirs.each do |base|
        Dir["#{base}**/*.rb"].each do |file|
          model_name = file.gsub(/^#{base}([\w_\/\\]+)\.rb/, '\1')
          next if model_name.nil?
          next if ::ActiveRecord::Base.send(:subclasses).detect { |model| model.name == model_name }
          begin
            model_name.camelize.constantize
          rescue LoadError
            model_name.gsub!(/.*[\/\\]/, '').nil? ? next : retry
          rescue NameError
            next
          end
        end
      end
    end
    
    def record_declaration(model, declaration_id, code)
      @declarations[model] ||= {}
      @declarations[model][declaration_id.to_sym] = code
    end
    
  end
end