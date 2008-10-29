# Include hook code here
require "plugin_bios"
ActionController::Base.class_eval do
	include PluginBios
end
