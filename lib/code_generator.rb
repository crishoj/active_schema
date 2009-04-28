module ActiveSchema
  class CodeGenerator
    extend ActiveSupport::Memoizable
    
    def initialize
      @declarations = {}
    end
    
    def code_path
      "#{RAILS_ROOT}/lib/#{module_name.underscore}.rb"
    end

    def regenerate
      puts "Loading models..."
      load_models ["#{RAILS_ROOT}/app/models/"]
      @models = ::ActiveRecord::Base.send(:subclasses)
      filter_models!
      examine_models
      build_declarations
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

    def filter_models!
      puts "#{@models.size} candidate models:\n  #{@models.map(&:name).sort.to_sentence}"
      reject_models "abstract class models" do |models|
        models.select { |model| model.abstract_class? }
      end
      reject_models "STI class models" do |models|
        models.select { |model| model != model.base_class }
      end
      reject_models "models without tables" do |models|
        models.select { |model| not model.table_exists? }
      end
    end

    def reject_models(desc)
      reject = yield @models
      puts "Rejecting #{reject.count} #{desc}:\n #{reject.map(&:name).sort.to_sentence}"
      @models = @models - reject
    end

    def examine_models
      @models.each do |model|
        puts "Examining #{model.name}"
        examine(model)
      end
    end

    def build_declarations
      code = "module #{module_name}\n\n"
      @declarations.sort_by { |model, associations|
        model.name
      }.each do |model,associations|
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

    def table_model_map
      returning Hash.new do |map|
        @models.each {|model| map[model.table_name] = model}
      end
    end
    memoize :table_model_map
    
  end
end