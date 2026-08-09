# `bin/rails hobo:tags` -- the catalogue of an application, with its owners.
#
# The list is only true once everything that defines tags has loaded, and in
# development that is not the case until the pages are derived, so it eager
# loads first: `to_prepare` is where the derivation engine runs.
namespace :hobo do

  desc "List the tags of this application and the gem that defines each one"
  task :tags => :environment do
    require "hobo/tag_index"
    Rails.application.eager_load!
    puts Hobo::TagIndex.new.render
  end

end
