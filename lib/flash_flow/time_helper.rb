require 'time'

module FlashFlow
  module TimeHelper

    def with_time_zone(tz_name)
      prev_tz = ENV['TZ']
      ENV['TZ'] = tz_name
      yield
    ensure
      ENV['TZ'] = prev_tz
    end

    def massage_time(time)
      case time
        when Time
          time
        when NilClass
          Time.now
        else
          Time.parse(time)
      end
    end

    def two_weeks
      60 * 60 * 24 * 14
    end

    module_function :with_time_zone, :massage_time, :two_weeks

  end
end
