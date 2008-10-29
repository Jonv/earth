# PluginBios
module PluginBios
	def self.included(base)
		base.send :extend, TagMethods
	end

	module TagMethods
		def acts_as_add_tab(title, controller, action)
			$the_sections << action
			$tab_info << {:title => title, :controller => controller, :action => action}
		end

		def acts_as_add_field_tag(name, params)
			$field_tag << { :name => name, :params => params}
		end
	end
end
