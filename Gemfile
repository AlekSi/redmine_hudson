module RedmineHudson
  def self.gems_for_cucumber
    gem "rspec"
    gem "rspec-rails"
    gem "cucumber"
    gem "cucumber-rails"
    gem "database_cleaner"
    gem "webrat"
  end
end

group :test do
  RedmineHudson::gems_for_cucumber
end

group :cucumber do
  RedmineHudson::gems_for_cucumber
end
