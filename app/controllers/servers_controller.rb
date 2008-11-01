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

class ServersController < ApplicationController

  # GET /servers
  # GET /servers.xml
  
  def initialize
	@size_type = @@webapp_config["size_type"].to_sym
  end
  
  def index
    Earth::File::with_filter do
      @servers = Earth::Server.find(:all)

      respond_to do |format|
        format.html # index.rhtml
        format.xml  { render :xml => @servers.to_xml }
      end
    end
  end

  # GET /servers/1
  # GET /servers/1.xml
  def show
    Earth::File::with_filter do
      @server = Earth::Server.find_by_name(params[:server])
      
      @users_space_usages = Earth::File.find(:all,
                                              :select => "sum(files.bytes) as space_usage, files.uid",
                                              :joins => "join directories on files.directory_id = directories.id",
                                              :group => "files.uid, directories.server_id",
                                              :conditions => [ "server_id = ? ", @server.id ])

      respond_to do |format|
        format.html # show.rhtml
        format.xml  { render :xml => @server.to_xml }
      end
    end
  end

  # GET /servers/1;edit
  def edit
    Earth::File::with_filter do
      @server = Earth::Server.find_by_name(params[:server])
    end
  end

  # PUT /servers/1
  # PUT /servers/1.xml
  def update
    @server = Earth::Server.find(params[:id])

    respond_to do |format|
      if @server.update_attributes(params[:server])
        flash[:notice] = 'Server was successfully updated.'
        format.html { redirect_to :action => "show", :params => { :server => @server.name } }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @server.errors.to_xml }
      end
    end
  end


  # GET /servers/1;configure
  def configure
    Earth::File::with_filter do
      @server = Earth::Server.find_by_name(params[:server])
    end
  end

  # PUT /servers/2
  # PUT /servers/2.xml
  def startdaemon
    @server = Earth::Server.find(params[:id])
    @server.fork_daemon
    render :update do |page|
      # update the status
      page.replace_html 'daemon_status_message', "<font color=green>[ Starting daemon . . . (~5s) ]</font>"
      # disable the start button
      page << "document.getElementById('start_daemon_button').disabled = true;"
      # highlight the updated div - so client notices
      page.visual_effect :highlight, 'daemon_status_message'
    end
  end


  # PUT /servers/2
  # PUT /servers/2.xml
  def restartdaemon
    @server = Earth::Server.find(params[:id])
    @server.refork_daemon
    render :update do |page|
      # update the status
      page.replace_html 'daemon_status_message', "<font color=green>[ Restarting daemon . . . (~5s) ]</font>"
      # disable the start button
      page << "document.getElementById('restart_daemon_button').disabled = true;"
      # highlight the updated div - so client notices
      page.visual_effect :highlight, 'daemon_status_message'
    end
  end

  # PUT /servers/2
  # PUT /servers/2.xml
  def cleardaemon
    @server = Earth::Server.find(params[:id])
    # @server.unfork_daemon
    @server.clear_daemon
    render :update do |page|
      # update the status
      page.replace_html 'daemon_status_message', "<font color=blue>[ Clearing data on localhost . . . (~5s) ]</font>"
      # disable the clear daemon button
      page << "document.getElementById('clear_daemon_button').disabled = true;"
      # highlight the updated div - so client notices
      page.visual_effect :highlight, 'daemon_status_message'
    end
  end

  # POST /servers/1;statusdaemon
  def statusdaemon  
    @server = Earth::Server.find(params[:id])      
    render :update do |page|
      page.replace_html 'daemon_status_message', "<font color=green>#{@server.get_daemon_status}</font>"
    end
  end

  # POST /servers/1;benchmark
  def benchmarked  
    @server = Earth::Server.find(params[:id])      
    render :update do |page|
      # update benchmark message
      page.replace_html 'daemon_benchmark', "<font color=green>[ #{@server.get_benchmark}]</font>"
      page.visual_effect :highlight, 'daemon_benchmark'
    end
  end

  # PUT /servers/2
  # PUT /servers/2.xml
  def stopdaemon
    @server = Earth::Server.find(params[:id])
    @server.unfork_daemon
    render :update do |page|
      # update the status
      page.replace_html 'daemon_status_message', "<font color=red>[ Stopping daemon . . . (~1s) ]</font>"
      # disable the stop button
      page << "document.getElementById('stop_daemon_button').disabled = true;"
      # highlight the updated div - so client notices
      page.visual_effect :highlight, 'daemon_status_message'
    end
  end

  # PUT /servers/1
  # PUT /servers/1.xml
  def adddir
    @server = Earth::Server.find(params[:id]) 
    @added = false
    @val = params[:directory_name]
    if @val != ''
      @server.add_directory(@val)
      @added = true
    end
    render :update do |page|
      # update the status
      if @added      
        page.replace_html 'updated_directory_message', "<font color=blue>[ Adding '#{@val}' directory. (~5s) ]</font>"
      else
        page.replace_html 'updated_directory_message', "<font color=blue>[ Please specify directory name. ]</font>"
      end
      # highlight the updated div - so client notices
      page.visual_effect :highlight, 'updated_directory_message'
    end
  end
  
  # PUT /servers/1
  # PUT /servers/1.xml
  def removedir
  	@server = Earth::Server.find(params[:id])  	
  	@removed = false
  	@value = params[:dir_path]
  	if @value != ''
  		@server.remove_directory(@value)
  		@removed = true
  	end
  	render :update do |page|
  		# update the status
  		if @removed
  			page.replace_html 'updated_directory_message', "<font color=blue>[ Removing '#{@value}' directory. (~1s) ]</font>"
  		else
  			page.replace_html 'updated_directory_message', "<font color=blue>[ Please verify directory name. ]</font>"	
  		end
  		# highlighted the updated div - so client notices
  		page.visual_effect :highlight, 'updated_directory_message'
  	end
  end

end
