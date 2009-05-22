namespace :active_schema do
  namespace :generate do
    task :associations => :environment do
      ActiveSchema::ForeignKeys::AssociationsGenerator.new.regenerate
    end

    task :validations => :environment do
      ActiveSchema::Constraints::ValidationsGenerator.new.regenerate
    end
  end

  namespace :update do

    desc "generate associations from foreign key relationships"
    task :associations do
      stale = "#{RAILS_ROOT}/lib/generated_associations.rb"
      File.unlink(stale) if File.exists?(stale)
      Rake::Task['active_schema:generate:associations'].invoke
    end

    desc "generate validations from table constraints"
    task :validations do
      stale = "#{RAILS_ROOT}/lib/generated_validations.rb"
      File.unlink(stale) if File.exists?(stale)
      Rake::Task['active_schema:generate:validations'].invoke
    end

  end
end