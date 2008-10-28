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

require 'openssl'

require File.join(File.dirname(__FILE__), 'earth_plugin')
#require File.join(File.dirname(__FILE__), '..', '..', 'app', 'models','earth','extension_point')
class PluginManagerError < RuntimeError
  def initialize(message)
    @message = message
  end

  def to_s
    @message
  end
end

class PluginManager

  @@plugin_module_counter = 1

  def initialize
    @trusted_certificates = nil
  end

  def trusted_certificates
    if @trusted_certificates.nil?
      @trusted_certificates = []
      trusted_certificate_directory = File.join(File.dirname(__FILE__), "..", "..", "config", "certificates")
      Dir.entries(trusted_certificate_directory).each do |filename| 
        certificate_file = File.join(trusted_certificate_directory, filename)
        if File.file?(certificate_file) and File.readable?(certificate_file)
          begin
            certificate = OpenSSL::X509::Certificate.new(File::read(certificate_file))
            @trusted_certificates << certificate
            #puts "Loaded certificate from #{certificate_file} (#{certificate.subject})"
          rescue
            puts "WARNING: cannot load certificate from #{certificate_file}"
          end
        end
      end
      if @trusted_certificates.empty?
        raise PluginManagerError, "No certificates installed"
      end
    end
    @trusted_certificates
  end

  def sign(plugin_filename, private_key)
    code = File.read(plugin_filename)
    signature = private_key.sign(OpenSSL::Digest::SHA1.new, code)
    signature_filename = plugin_filename + ".sha1"
    File.open(signature_filename, "w") { |f| f.write signature }
  end

  def get_plugin_class(code, signature)

    signer = nil
    trusted_certificates.each do |trusted_certificate|
      begin 
        signer = trusted_certificate.subject if trusted_certificate.public_key.verify(OpenSSL::Digest::SHA1.new, signature, code)
      rescue
      end
    end
    if signer.nil?
      raise PluginManagerError, "Plugin signature could not be verified"
    end

    EarthPlugin.on_inheritance do |child|
      @plugin_class = child
    end
    
    eval("module PluginModule_#{@@plugin_module_counter}\n" + code + "\nend\n")
    @@plugin_module_counter +=1
    new_plugin_class = @plugin_class

    EarthPlugin.validate_plugin_class(new_plugin_class)

    new_plugin_class
  end

  def uninstall(plugin_name)
      uninstall_plugin=nil
    begin
      ENV["RAILS_ENV"] = "development"
      require File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment')

      uninstall_plugin = Earth::PluginDescriptor.find(:first, :conditions =>{ :name => plugin_name })   

    rescue Errno::ENOENT
       raise PluginManagerError, "No such plugin installed  in  database!"
       
       # Ken: Stop the script from continuing to remove the plugin.
       return false
    end
    destroy_related_extension_point(plugin_name)
    
    # Run plugin migration
    code = Base64.decode64(uninstall_plugin.code)
    signature = Base64.decode64(uninstall_plugin.sha1_signature)
    
    uninstalled_plugin_class = get_plugin_class(code, signature) 
    if uninstalled_plugin_class.respond_to? 'migration_down'
      uninstalled_plugin_class.migration_down
    end
    
    #TODO uninstall all related plugins
    #Finally, delete the plugin
    Earth::PluginDescriptor::delete(uninstall_plugin)
  end
    

  def install_from_file(plugin_filename,ext_point_name,host_plugin)
    code = File.read(plugin_filename)
    
    signature_filename = plugin_filename + ".sha1"
    begin
      signature = File.read(signature_filename)
    rescue Errno::ENOENT
      raise PluginManagerError, "Plugin signature not found in #{signature_filename}"
    end

    ENV["RAILS_ENV"] = "development"
    require File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment')

    new_plugin_class = get_plugin_class(code, signature)

    existing_plugin = Earth::PluginDescriptor::find(:first, :conditions => { :name => new_plugin_class.plugin_name })
    if not existing_plugin.nil? 
      if existing_plugin.version == new_plugin_class.plugin_version
        raise PluginManagerError, "Refusing to install plugin: This version of this plugin is already installed (#{existing_plugin.version} == #{new_plugin_class.plugin_version})."
      elsif existing_plugin.version > new_plugin_class.plugin_version
        raise PluginManagerError, "Refusing to install plugin: A newer version of this plugin is already installed (#{existing_plugin.version} > #{new_plugin_class.plugin_version})."
      end
    end
    
    # Ken: Due to the problem with PostgresSQL, Ruby and Rails not sharing a 
    #      common ground with UTF-8 encoding, we will now encode all codes 
    #      and signatures into Base64 strings and store it into the databse 
    #      without loosing integrity
    b64_code = Base64.b64encode(code)
    b64_signature = Base64.b64encode(signature)

     #Ida:Find extension point id ,in terms of the extension_point_name and host_name.
    extension_point=Earth::ExtensionPoint.find(:first, :conditions => { :name => ext_point_name,:host_plugin=>host_plugin })
    extension_point_id=extension_point.id
     
    if existing_plugin
      Earth::PluginDescriptor::delete(existing_plugin)
      #delete all related extension points because a new version is installed
      #if the new version has any extension points, the y will inserted later
      destroy_related_extension_point(existing_plugin.name)
    end
    #Earth::PluginDescriptor::delete(existing_plugin) if existing_plugin
    #Earth::PluginDescriptor::create(:name => new_plugin_class.plugin_name, :version => new_plugin_class.plugin_version, :code => code, :sha1_signature => signature)
    Earth::PluginDescriptor::create(:name => new_plugin_class.plugin_name, :version => new_plugin_class.plugin_version, :code =>    b64_code, :sha1_signature => b64_signature,:extension_point_id =>extension_point_id)
    
    # Run plugin migration
    if new_plugin_class.respond_to? 'migration_up'
      new_plugin_class.migration_up
    end
  end

  def load_plugin(name, last_loaded_version)
    if last_loaded_version
      newPlugin = Earth::PluginDescriptor::find(:first, :conditions => [ "name = ? and version >= ?", name, last_loaded_version ])
    else
      newPlugin = Earth::PluginDescriptor::find(:first, :conditions => [ "name = ?", name ])
    end
    return nil unless newPlugin

    # Ken: Since we stored the plugins in Base64 strings, we will need to decode
    #      them before we use.
    code = Base64.decode64(newPlugin.code)
    signature = Base64.decode64(newPlugin.sha1_signature)
    
    #new_plugin_class = get_plugin_class(newPlugin.code, newPlugin.sha1_signature)
    new_plugin_class = get_plugin_class(code, signature)
    
    #logger.info("New plugin \"#{name}\" available (version #{validated_plugin_class.plugin_version})")
    
    new_plugin_class.new
  end
  
  def list_plugins(flag, plugin)
    ENV["RAILS_ENV"] = "development"
    require File.join(File.dirname(__FILE__), '..', '..', 'config', 'environment')
    plugins = nil
    
    if flag == "all" and plugin == "none"
      plugins = Earth::PluginDescriptor::find(:all, :select => "name as plugin_name", 
                                              :order => "plugin_name")
                                    
    elsif flag == "info" and plugin == "none"
      plugins = Earth::PluginDescriptor.find(:all, 
                        :select => "plugin_descriptors.name as plugin_name, 
                                    plugin_descriptors.version,
                                    extension_points.name as extension,
                                    extension_points.host_plugin",
                        :joins => "left join extension_points on
                                    extension_points.id = plugin_descriptors.extension_point_id",
                        :order => "plugin_name")
    else
      plugins = Earth::PluginDescriptor.find(:all, 
                        :select => "plugin_descriptors.name as plugin_name, 
                                    plugin_descriptors.version,
                                    extension_points.name as extension,
                                    extension_points.host_plugin",
                        :joins => "left join extension_points on
                                    extension_points.id = plugin_descriptors.extension_point_id",
                        :conditions => [ "plugin_descriptors.name = ?", plugin], 
                        :order => "plugin_name")
    end
    
    if plugins.length == 0 or plugins == nil
      if plugin == "" then
        puts "There is no plugin installed."
      else
        puts "There is no plugin installed with the name '" + plugin + "'."
      end
    else
      plugins.each do |plugin|
        if flag == "all"
          puts plugin.plugin_name
        else
          puts plugin.plugin_name + "( v" + plugin.version.to_s  + " ) <= " + plugin.host_plugin + "." + plugin.extension
        end
      end
    end
  end
  
  private
  def destroy_related_extension_point(plugin_name)
    plugin_name = plugin_name.sub('Earth','')
    related_extension_points = Earth::ExtensionPoint.find(:all, :conditions => {:host_plugin => plugin_name})
    for ext in related_extension_points do
      ext.destroy
    end
  end
  
end
