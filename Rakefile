require 'yaml'
require 'active_record'

begin
  require 'rspec/core/rake_task'

  RSpec::Core::RakeTask.new(:spec) do |t|
    t.verbose    = false
    t.rspec_opts = "-fp"
  end

  task :default => :spec
rescue LoadError
end

namespace :db do

  #ActiveRecord::Migration.verbose = false

  desc "Migrate the database schema through db/migrate files."
  task :migrate => :environment do
    ActiveRecord::Migrator.migrate('db/migrate', ENV["VERSION"] ? ENV["VERSION"].to_i : nil)
  end

  desc "Drop all tables from the default project database."
  task :down => :environment do
    ActiveRecord::Migrator.down('db/migrate')
  end

  # Only to be possible run [ rake db:task ] outside the application.
  task :environment do
    ActiveRecord::Base.establish_connection (
      YAML::load( File.open('config/database.yml') )[ ENV["RAKE_ENV"] ||= 'production'] )
  end

end

namespace :postfix do

  desc "Start a Local Postfix Mail Server"
  task :start do
    %x[ sudo postfix start > /dev/null 2>&1 ]
  end

  desc "Stop a Local Postfix Mail Server"
  task :stop do
    %x[ sudo postfix stop  > /dev/null 2>&1 ]
  end

end