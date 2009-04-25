namespace :active_schema do
  namespace :update do

    desc "generate associations from foreign key relationships"
    task :associations => :environment do
      ActiveSchema::ForeignKeys::AssociationsGenerator.new.regenerate
    end

    desc "generate validations from table constraints"
    task :validations => :environment do
      ActiveSchema::Constraints::ValidationsGenerator.new.regenerate
    end

  end
end