require 'redmine'
require 'dispatcher'
require 'hudson_application_hooks'
require 'query_patch'

Dispatcher.to_prepare :redmine_hudson do
  require_dependency 'setting'
end

Redmine::Plugin.register :redmine_hudson do
  name 'Redmine Hudson plugin'
  author 'Toshiyuki Ando r-labs'
  url "http://www.r-labs.org/repositories/show/hudson" if respond_to?(:url)
  description 'This is a Hudson plugin for Redmine'
  version '1.0.6'
  requires_redmine :version_or_higher => '0.8.0'

  project_module :hudson do
    permission :view_hudson, {:hudson => [:index, :history]}
    permission :build_hudson, {:hudson => [:build]}, :require => :member
    permission :edit_hudson_settings, {:hudson_settings => [:edit, :joblist, :delete_builds, :delete_history]}, :require => :member
  end

  menu :project_menu, :hudson, { :controller => :hudson, :action => :index }, :param => :id, :caption => :label_hudson

  activity_provider :hudson, :class_name => 'HudsonBuild', :default => true

  settings(:default => {
             'autofetch' => "true",
             'job_description_format' => "hudson",
             'query_limit_builds_each_job' => 100,
             'query_limit_changesets_each_job' => 100
            },
           :partial => 'hudson_settings/redmine_hudson_settings')

  Redmine::WikiFormatting::Macros.register do
    desc "This is my macro link to hudson"
    macro :build do |obj, args|
      return nil if args.length < 2 # require JobName, BuildNumber
      return nil if @project == nil
      hudson = Hudson.find_by_project_id(@project.id)
      return nil if hudson == nil
      name = args[0].strip
      number = args[1].strip
      return link_to "Build:#{name} ##{number}", URI.escape("#{hudson.settings.url}job/#{name}/#{number}/")
    end
  end

end

Dispatcher.to_prepare do
  Query.send( :include, RedmineHudson::RedmineExt::QueryPatch)
end
