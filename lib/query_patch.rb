# $Id$

require 'redmine/version'

module RedmineHudson
  module RedmineExt
    module QueryPatchFor09Later
      def sql_for_field_with_redmine_hudson(field, operator, value, db_table, db_field, is_custom_filter=false)
        case field
        when "hudson_build"
          return sql_for_hudson_build(field, operator, value)

        when "hudson_job"
          return sql_for_hudson_job(field, operator, value)

        else
           return sql_for_field_without_redmine_hudson(field, operator, value, db_table, db_field, is_custom_filter)
        end
      end
    end #QueryPatchFor09

    module QueryPatchFor08
      def sql_for_field_with_redmine_hudson(field, value, db_table, db_field, is_custom_filter)
        operator = operator_for field
        case field
        when "hudson_build"
          return sql_for_hudson_build(field, operator, value)

        when "hudson_job"
          return sql_for_hudson_job(field, operator, value)

        else
           return sql_for_field_without_redmine_hudson(field, value, db_table, db_field, is_custom_filter)
        end
      end
    end #QueryPatchFor08

    module QueryPatch
      def self.included(base) #:nodoc:
        base.class_eval do

          unloadable

          if Redmine::VERSION::MAJOR == 0 && Redmine::VERSION::MINOR < 9 then
            include RedmineHudson::RedmineExt::QueryPatchFor08
          else
            include RedmineHudson::RedmineExt::QueryPatchFor09Later
          end

          def available_filters_with_redmine_hudson
            return @available_filters if @available_filters

            available_filters_without_redmine_hudson

            return @available_filters unless project

            hudson = Hudson.find_by_project_id(project.id)

            job_conditions = "#{HudsonJob.table_name}.project_id = #{project.id}"
 
            @hudson_filters = []
            @hudson_filters <<
              HudsonQueryFilter.new("hudson_job",
                                    { :type => :list_optional, :order => @available_filters.size + 1,
                                      :values => HudsonJob.find(:all, :conditions => job_conditions, :order => "#{HudsonJob.table_name}.name").collect {|job|
                                                  next unless hudson.settings.job_include?(job.name)
                                                  [job.name, job.id.to_s]
                                                }
                                    },
                                    HudsonBuild.table_name,
                                    "hudson_job_id")
            @hudson_filters <<
              HudsonQueryFilter.new("hudson_build",
                                    { :type => :integer, :order => @available_filters.size + 2 },
                                    HudsonBuild.table_name,
                                    "number")

            @hudson_filters.each do |filter|
              @available_filters[filter.name] = filter.available_values
            end
            return @available_filters
          end

          alias_method_chain :available_filters, :redmine_hudson unless method_defined?(:available_filters_without_redmine_hudson)
          alias_method_chain :sql_for_field, :redmine_hudson unless method_defined?(:sql_for_field_without_redmine_hudson)

          def sql_for_hudson_build(field, operator, value)
            return sql_for_always_false unless project

            if filters.has_key?('hudson_job')
              cond_jobs = conditions_for('hudson_job', operator_for('hudson_job'), values_for('hudson_job'))
            else
              jobs = HudsonJob.find(:all, :conditions => ["#{HudsonJob.table_name}.project_id = ?", project.id])
              cond_jobs = "#{HudsonBuild.table_name}.hudson_job_id in (" + jobs.collect{|target| "#{connection.quote_string(target.id.to_s)}"}.join(",") + ")"
            end

            builds = HudsonBuild.find(:all, :conditions => ["#{cond_jobs} and #{conditions_for(field, operator, value)}"])

            return sql_for_always_false if builds.length == 0

            cond_builds = builds.collect{|target| "#{connection.quote_string(target.id.to_s)}"}.join(",")

            hbchangesets = HudsonBuildChangeset.find(:all, :conditions => ["#{HudsonBuildChangeset.table_name}.hudson_build_id in (#{cond_builds})"])

            return sql_for_always_false if hbchangesets.length == 0

            value_revisions = hbchangesets.collect{|target| "#{connection.quote_string(target.revision.to_s)}"}.join(",")
            sql = "#{Issue.table_name}.id in"
            sql << "(select changesets_issues.issue_id from changesets_issues"
            sql << " where changesets_issues.changeset_id in"
            sql << "  (select #{Changeset.table_name}.id from #{Changeset.table_name}"
            sql << "   where #{Changeset.table_name}.repository_id = #{project.repository.id}"
            sql << "    and   #{Changeset.table_name}.revision in (#{value_revisions})"
            sql << " )"
            sql << ")"
            return sql
          end

          def sql_for_hudson_job(field, operator, value)
            return sql_for_always_false unless project

            if filters.has_key?('hudson_build')
              return sql_for_always_true
            end

            builds = HudsonBuild.find(:all, :conditions => "#{conditions_for(field, operator, value)}")

            return sql_for_always_false if builds.length == 0

            cond_builds = builds.collect{|target| "#{connection.quote_string(target.id.to_s)}"}.join(",")

            hbchangesets = HudsonBuildChangeset.find(:all, :conditions => ["#{HudsonBuildChangeset.table_name}.hudson_build_id in (#{cond_builds})"])

            return sql_for_always_false if hbchangesets.length == 0

            value_revisions = hbchangesets.collect{|target| "#{connection.quote_string(target.revision.to_s)}"}.join(",")

            sql = "#{Issue.table_name}.id in"
            sql << "(select changesets_issues.issue_id from changesets_issues"
            sql << " where changesets_issues.changeset_id in"
            sql << "  (select #{Changeset.table_name}.id from #{Changeset.table_name}"
            sql << "   where #{Changeset.table_name}.repository_id = #{project.repository.id}"
            sql << "    and   #{Changeset.table_name}.revision in (#{value_revisions})"
            sql << " )"
            sql << ")"
            return sql
          end

          # conditions always true
          def sql_for_always_true
            return "#{Issue.table_name}.id > 0"
          end

          # conditions always false
          def sql_for_always_false
            return "#{Issue.table_name}.id < 0"
          end

          def conditions_for(field, operator, value)
            retval = ""

            available_filters
            return retval unless @hudson_filters
            filter = @hudson_filters.detect {|hfilter| hfilter.name == field}
            return retval unless filter
            db_table = filter.db_table
            db_field = filter.db_field

            case operator
            when "="
              retval = "#{db_table}.#{db_field} IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + ")"
            when "!"
              retval = "(#{db_table}.#{db_field} IS NULL OR #{db_table}.#{db_field} NOT IN (" + value.collect{|val| "'#{connection.quote_string(val)}'"}.join(",") + "))"
            when "!*"
              retval = "#{db_table}.#{db_field} IS NULL"
              retval << " OR #{db_table}.#{db_field} = ''"
            when "*"
              retval = "#{db_table}.#{db_field} IS NOT NULL"
              retval << " AND #{db_table}.#{db_field} <> ''"
            when ">="
              retval = "#{db_table}.#{db_field} >= #{value.first.to_i}"
            when "<="
              retval = "#{db_table}.#{db_field} <= #{value.first.to_i}"
            when "!~"
              retval = "#{db_table}.#{db_field} NOT LIKE '%#{connection.quote_string(value.first.to_s.downcase)}%'"
            end
            return retval
          end
        end
      end
    end #QueryPatch
  end #RedmineExt
end #RedmineHudson
