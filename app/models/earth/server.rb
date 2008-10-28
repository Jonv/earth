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
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'socket'

module Earth

  class Server < ActiveRecord::Base
    has_many :directories, :dependent => :delete_cascade, :order => :lft

    @@config = nil    
    def self.config
      @@config = ApplicationController::webapp_config unless @@config
      @@config
    end
    
    def self.heartbeat_grace_period
      self.config["heartbeat_grace_period"].to_i
    end

    def Server.this_server
      Server.find_or_create_by_name(ENV["EARTH_HOSTNAME"] || this_hostname)
    end
    
    def Server.this_hostname
      Socket.gethostbyname(Socket.gethostname)[0]
    end
    
    def self.filter_and_add_bytes(servers,options={})
      show_empty = options[:show_empty]
      any_empty = false
      
      servers_and_bytes = servers.map do |s|
        size = s.size
        any_empty = true if size.count == 0
        if show_empty || size.count > 0
          if @size_type == :disk
			[s, size.diskSize]
 		else
 			[s, size.bytes]
 		end
        end
      end
      
      [servers_and_bytes.compact, any_empty]
    end
    
    def size
      size_sum = Size.new(0, 0, 0)
      Earth::Directory.roots_for_server(self).each do |d|
        size_sum += d.size
      end
      size_sum
    end

    def has_files?
      size.count > 0
    end
    
    def heartbeat
      self.heartbeat_time = Time.now.utc
      save!
    end
    
    def daemon_alive?
      if heartbeat_time.nil? or daemon_version.nil?
        false
      else
        (heartbeat_time + heartbeat_interval + Earth::Server.heartbeat_grace_period) >= Time::now
      end
    end

    def cache_complete?
      roots = Earth::Directory.roots_for_server(self) 
      (not roots.empty?) and roots.all? { |d| d.cache_complete? and not d.children.empty? }
    end

    def fork_daemon
      initialize_daemon
      fork do
        puts "Launching daemon in background"
        exec("#{@daemon} start")
      end
    end
   
    def refork_daemon
      initialize_daemon
      fork do
        puts "Restarting daemon in background"
        exec("#{@daemon} restart")
      end
    end   
    
    def get_daemon_pid
      if @daemon_pid.nil?
        @daemon_pid = fork_daemon
        "[server.rb] Daemon not running - Starting daemon instead"
      else
        @daemon_pid = refork_daemon
      end
    end 

    def unfork_daemon
      initialize_daemon
      fork do
        puts "Killing daemon"
        exec("#{@daemon} stop")
      end
    end
    
    def clear_daemon
      initialize_daemon
      fork do
        puts "Clearing daemon"
        exec("#{@daemon} clear")
      end
    end
    
    def initialize_daemon
      @daemon = "script/earthd"
    end

    def get_daemon_status
      initialize_daemon
      fork do
        puts "Getting daemon status"
        exec("#{@daemon} status")
      end  
      @info
    end

   def add_directory(directory_name)
     initialize_daemon
     fork do
       puts "Adding dir to monitor"
       exec("#{@daemon} add #{directory_name}")
     end
   end
   
   def remove_directory(directory_path)
   	initialize_daemon
   	fork do
   		puts "Removing monitored directory"
   		exec("#{@daemon} remove #{directory_path}")
   	end
 	 end
 end
end
