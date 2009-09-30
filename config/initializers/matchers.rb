# this module contains methods to extract information out of log lines.
# matcher method must exhibit the following behavior:
#
#   accept a log line and extract info as a hash where the domain corresponds to som db column.
#   return false (or nil) if the line cannot be matched.
#
module Matchers

  # this regexp is used to prefilter log files with egrep|zegrep (which can speed up things quite a bit)
  PRE_MATCH = 'Completed in|Processing|Session ID'

  # log line format @XING
  # Jul 08 07:42:53 ext-xeapp52-5 rails[31023] user[Anonymous]: ... rails log content ...
  # Jul 08 07:42:53 ext-xeapp52-5 rails[31023] user[243242356]: ... rails log content ...
  #
  # standard syslog format would be
  # Jul 08 07:42:53 ext-xeapp52-5 rails[31023]: ... rails log content ...
  # the following matcher works in both cases
  # unlike the other matchers, this one returns an array of [host, process_id, user_id, remaining_log_line_content]
  SYSLOG_LINE_SPLITTER = lambda do |line|
    line =~ / ([\S]+) [\S]+\[(\d+)\](?: user\[(.+)\])?: (.*)/ and
      Regexp.last_match.captures
  end

  # Use this splitter if you are using the default Rails logger. However, if you have multiple
  # processes logging to the same log file (eg with Passenger), you will end up with a mess.
  RAILS_LOG_LINE_SPLITTER = lambda do |line|
    process_id = 0
    user_id = nil
    ['localhost', process_id, user_id, line]
  end

  LOG_LINE_SPLITTER = SYSLOG_LINE_SPLITTER

  # the proccessing line. mandatory matcher.
  PROCESSING = lambda do |line|
    line =~ /^Processing ([\S]+).*\(for (.+) at (.*)\)/ and
      { :page => $1, :ip => $2, :started_at => $3 }
  end

  # default rails session log line. optional matcher.
  SESSION_RAILS = lambda do |line|
    line =~ /^Session ID: ([\S]+)/ and
      { :session_id => $1 }
  end

  # @XING we also log whether the session was created during request processing
  SESSION_XING = lambda do |line|
    line =~ /^Session ID: ([\S]+) \(([XN])\)/ and
      { :session_id => $1, :new_session => ($2 == 'N') ? 1 : 0 }
  end

  # default rails completed line. mandatory matcher.
  # Completed in 1517.781ms (View: 26.129, DB: 26.009) | 200 OK [http://localhost/marketplace/]
  COMPLETED_RAILS = lambda do |line|
    line =~ /^Completed in ([\S]+)ms \(View: ([\S]+), DB: ([\S]+)\) \| (\d+) / and
      {
        :total_time => $1.to_f,
        :view_time => $2.to_f,
        :db_time => $3.to_f,
        :response_code => $4.to_i,
      }
  end

  # completed line regexp: complicated by the fact that the log file
  # format @XING changed over time and we want to be able to parse old logfiles
  #
  # Aug 26 15:37:29 pc-skaes-3 rails[74535] user[3502094]: Completed in 1517.781ms (View: 26.129, DB: 26.009(17,0), API: 41.166(1), SR: 30.590(3), MC: 6.447(9r,0m), GC: 628.893(6), HP: 0(1616240,591402,35515800)) | 200 OK [http://localhost/marketplace/]
  # Jul 27 16:25:29 pc-skaes-3 rails[3161] user[5926542]: Completed in 2352.498ms (View: 183.980, DB: 53.292(15), API: 46.657(1), SR: 7.638(3), MC: 6.345(9r,0m), GC: 970.501(10)) | 200 OK [http://localhost/jobs]
  # Jun 28 06:00:49 ext-xeapp52-1 rails[25944] user[Anonymous]: Completed in 176.044ms (View: 0.000, DB: 0.000(0), API: 0.000(0), SR: 0.000(0), MC: 2.218(1r,1m)) |  [http://localhost/jobs/]
  COMPLETED_XING = lambda do |line|
    line =~ /^Completed in ([\S]+)ms \(View: ([\S]+), DB: ([\S]+)\((\d+)(?:,(\d+))?\), API: ([\S]+)\((\d+)\), SR: ([\S]+)\((\d+)\), MC: ([\S]+)\((\d+)r,(\d+)m\)(?:, GC: ([\S]+)\((\d+)\))?(?:, HP: ([\S]+)\((\d+),(\d+),(\d+)\))?\) \| (\d+)? / and
      {
        :total_time => $1.to_f,
        :view_time => $2.to_f,
        :db_time => $3.to_f,
        :db_calls => $4.to_i,
        :db_sql_query_cache_hits => $5.to_i,
        :api_time => $6.to_f,
        :api_calls => $7.to_i,
        :search_time => $8.to_f,
        :search_calls => $9.to_i,
        :memcache_time => $10.to_f,
        :memcache_calls => $11.to_i,
        :memcache_misses => $12.to_i,
        :gc_time => $13.to_f,
        :gc_calls => $14.to_i,
        :heap_growth => $15.to_i,
        :heap_size => $16.to_i,
        :allocated_objects => $17.to_i,
        :allocated_bytes => $18.to_i,
        :response_code => $19.to_i,
    }
  end

end # Matchers

RequestInfo.register_matcher Matchers::PROCESSING
RequestInfo.register_matcher Matchers::SESSION_XING
RequestInfo.register_matcher Matchers::COMPLETED_XING
#RequestInfo.register_matcher Matchers::COMPLETED_RAILS
