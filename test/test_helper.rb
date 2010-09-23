# $Id$
# Load the normal Rails helper
require File.expand_path(File.dirname(__FILE__) + '/../../../../test/test_helper')

# Ensure that we are using the temporary fixture path
Engines::Testing.set_fixture_path

def get_response(name)
  f = open(File.dirname(__FILE__) + "/responses/#{name}.xml")
  retval = f.read
  f.close
  return retval
end


# patch to detect slow tests

$_tests_run_times = {}

class ActiveSupport::TestCase
  setup :_start_timer
  def _start_timer
    @_start_time = Time.now
  end

  teardown :_stop_timer
  def _stop_timer
    $_tests_run_times[self.to_s] = Time.now - @_start_time
  end
end

at_exit do
  unless $! || Test::Unit.run?  # run tests only once
    exit_code = Test::Unit::AutoRunner.run

    if $_tests_run_times.present?
      res = $_tests_run_times.select{ |m, s| s > 1 }.sort_by(&:last).reverse[0, 20]
      if res.present?
        puts "\n\nTop #{res.count} slowest tests methods (including all setups and teardowns):"
        res.each { |l| puts "#{l.last.to_s[0, 4]} - #{l.first}" }
      end
    end

    exit exit_code
  end
end
