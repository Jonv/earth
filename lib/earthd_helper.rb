# Copyright (C) 2007 Rising Sun Pictures and Matthew Landauer
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

SECONDS_PER_MINUTE = 60
MINUTES_PER_HOUR = 60
HOURS_PER_DAY = 24

class Tee
  def initialize(log_file_name)
    @log_file = File.open(log_file_name, "a")
    $stdout.sync = true
  end
  def write(message)
    @log_file.write(message)
    $stdout.write(message)
  end
  def close
    @log_file.close
  end
end

class MultiLogger

  def initialize(loggers)
    @loggers = loggers
  end

  def progname=(progname)
    @loggers.each do |logger|
      logger.progname = progname
    end
  end

  def formatter=(formatter)
    @loggers.each do |logger|
      logger.formatter = formatter
    end
  end

  def datetime_format=(datetime_format)
    @loggers.each do |logger|
      logger.datetime_format = datetime_format
    end
  end

  def level=(level)
    @loggers.each do |logger|
      logger.level = level
    end
  end

  def add(severity, message = nil, progname = nil, &block)
    @loggers.each do |logger|
      logger.add(severity, message, progname, &block)
    end
  end
    
  def <<(msg)
    @loggers.each do |logger|
      logger << msg
    end
  end

  def debug(progname = nil, &block)
    @loggers.each do |logger|
      logger.debug(progname, &block)
    end
  end
      
  def info(progname = nil, &block)
    @loggers.each do |logger|
      logger.info(progname, &block)
    end
  end      
      
  def warn(progname = nil, &block)
    @loggers.each do |logger|
      logger.warn(progname, &block)
    end
  end
           
  def error(progname = nil, &block)
    @loggers.each do |logger|
      logger.error(progname, &block)
    end
  end
           
  def fatal(progname = nil, &block)
    @loggers.each do |logger|
      logger.fatal(progname, &block)
    end
  end
           
  def unknown(progname = nil, &block)
    @loggers.each do |logger|
      logger.unknown(progname, &block)
    end
  end
           
  def close
    @loggers.each do |logger|
      logger.close
    end
  end
   
end

def format_uptime(diff)
  s = ((diff)).floor
  m = ((diff / SECONDS_PER_MINUTE)).floor
  h = ((diff / SECONDS_PER_MINUTE / MINUTES_PER_HOUR)).floor
  d = ((diff / SECONDS_PER_MINUTE / MINUTES_PER_HOUR / HOURS_PER_DAY)).floor
  uptime = "#{s % SECONDS_PER_MINUTE}s"
  if m > 0
    uptime = "#{m % MINUTES_PER_HOUR}m #{uptime}"
    if h > 0
      uptime = "#{h % HOURS_PER_DAY}h #{uptime}"
      if d > 0
        uptime = "#{d}d #{uptime}"
      end
    end
  end
  uptime
end

#
# Test whether child is a (direct or indirect) sub-directory of parent
#
def subdirectory_of?(parent, child)
  while true
    child_his_parent = File.dirname(child)
    if parent == child_his_parent
      return true
    elsif child_his_parent.nil?
      return false
    elsif child_his_parent == child
      return false
    else
      child = child_his_parent
    end
  end
end

# This method is used to read status from a log file
# The status will be in the last line of that file
def read_status_from(status_log_file)
  last_line = last_line(status_log_file)
  status_info = ""
  status_info = parse_log_line(last_line) unless last_line.nil?
  status_info
end

#This method is used to return the last line of the passed file
def last_line(log_file)
  last_line = nil
  begin
      file = File.new(log_file, "r")
      counter = 0
      while (line = file.gets)
          counter = counter + 1
          last_line = line
      end
      file.close
      
      #This could be used if the performance is affected by the size of the log file
      #if number of lines is more than 500
      #empty the log file
      #if counter > 500
      #  file = File.new(log_file, "w")
      #  file.close
      #end
  rescue => err
      puts "Exception: #{err}"
      err
  end
  last_line
end

#This method is used parse a line in a log file
#A line in the log file will contain a key word DEBUG, WARN or INFO
#for earthd status, we will use INFO only
def parse_log_line(line)
  log_key_word = "INFO -- : "
  index = line.index(log_key_word)
  line = line[index+log_key_word.size, line.size] unless index.nil?
  line.strip
end