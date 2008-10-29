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

# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

require 'erb'

class ApplicationController < ActionController::Base
	#keane : added for ticket 42
require File.join(File.dirname(__FILE__), '..', '..',  'lib', 'earth_plugin_interface', 'earth_plugin.rb')
require File.join(File.dirname(__FILE__), '..', '..', 'lib','earth_plugins', 'search_by_kv_pairs.rb')
#----------------------------------------
# GUI plugins code: start
#-----------------------------------------
plugin_path = File.join(File.dirname(File.dirname(File.dirname(__FILE__))),'vendor', 'plugins')
  plugin_controller_path = File.join(File.dirname(__FILE__))
  Dir.foreach(plugin_path) do |item|
    file_plugin = File.join(plugin_path, item, 'plugin_cfg')
    if File.exist?(file_plugin)
       if File.readable? file_plugin
          if File.file? file_plugin
             file_content = IO.readlines(file_plugin)
             index = 0;
             while index < file_content.length
                if file_content[index].include? "#"
                  index += 1
                  next
                end
                file_line = file_content[index].split(',')
                p file_line
                if file_line[0]=="plugin_name"
                  controller_name = file_line[1].to_s.chop
                end
                if file_line[0]=="tab"
                  p "this is a tab"
                  p plugin_controller_path
                  p controller_name
                  if File.exist?(File.join(plugin_controller_path,controller_name+'_controller.rb'))
                    acts_as_add_tab(file_line[1], file_line[2],file_line[3].chop)
                  end
                end
                if file_line[0]=="field_tag"
                  if File.exist?(File.join(plugin_controller_path,controller_name+'_controller.rb'))
                    acts_as_add_field_tag(file_line[1],file_line[2].chop)
                  end
                end
                index += 1
             end
           end
       end
    end
  end
#----------------------------------------
# GUI plugins code: end
#-----------------------------------------

  @@webapp_config = YAML.load(ERB.new(File.read(File.join(File.dirname(__FILE__), "../../config/earth-webapp.yml"))).result)

  def self.webapp_config
    @@webapp_config
  end
  
  $plugin_session = {}

end
