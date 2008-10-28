module EarthApi
  # The +MetadataApi+ class provides methods to manage files metadata
  # Main methods:
  # 1- save_file_metadata
  # 2- delete_file_metadata
  # 3- delete_all_files_metadata_under_dir
  # 4- remove_metadata_for_plugin
  class MetadataApi
    
    # the +save_file_metadata+ save metadata for a given file
    # if there is already metdata for this file it will be deleted and the new ones will be saved
    # === Parameters:
    # * _file_ = a file object, represent a record in files table.
    #            this method will save metadata for this file
    # * _metadata_ = TODO
    # the metadata in a hash form: {key => value, key2 => value2,,,}
    # where: the (key) should corresponds to an attribute_name in metadata_attributes table
    # examples of metadata:
    # {"job" => "lor", "sequence" => "001", "shot" => "143"}
    # {"resolution" => 300}
    # {"file_type" => "JPG"}...etc
    def self.save_file_metadata(file, metadata)
      #delete any old metadata for this file
      attribute_names = metadata.keys
      delete_file_metadata(file, attribute_names)
      
      #bring the corresponding attribute Ids and types
      #create a array in the form: 
      # [{:attribute_id => ??, :attribute_type => ??, :value => ??}, {}, {},,,]
      metadata_with_att = metadata_with_attributes(metadata)                        
      
      # save file metdata
      for i in 0..metadata_with_att.size-1 do 
        #use the method create_metadata() 
        #create_metadata(file, {:value => metadata_with_att[i][:value], :metadata_attribute_id => metadata_with_att[i][:attribute_id]})
        create_metadata(file, metadata_with_att[i])
      end
    end
    
    
    #The +metadata_with_attributes+ method brings the corresponding attribute Ids and types
    #create a array in the form: 
    # [{:attribute_id => ??, :attribute_type => ??, :value => ??}, {}, {},,,]
    # === Parameters:
    # * _metadata_ = hash contains metadata in the form {key => value, key2, => value2,,,}
    # key = String should have an entry in the metadata_attributes
    # value = the metadata value
    def self.metadata_with_attributes(metadata)
      metadata_with_att = Array.new
      for i in 0..metadata.size-1 do
        attribute = Earth::MetadataAttribute.find_by_name(metadata.keys[i])
        unless attribute.nil?
          metadata_with_att << {:attribute_id => attribute.id, :attribute_type => attribute.metadata_type, :value => metadata.values[i]}
        end
      end
      metadata_with_att
    end
    
    # this method saves metadata on the needed table depending on its type
    # if metadata type is string, it will be saved in metadata_strings table
    # and so on
    # * _metadata_with_att_ = Hash in the form {:value => ??, :attribute_id => ??, :attribute_type => ??}
    def self.create_metadata(file , metadata_with_att)
      attributes = {:value => metadata_with_att[:value], :metadata_attribute_id => metadata_with_att[:attribute_id]}
      #check the metadata type to save it in the right table
      type = metadata_with_att[:attribute_type]
      if(type == "string")
        file.metadata_strings.create(attributes)
        #else if(type == "integer")
        #file.metadata_integers.create(attributes)
        #and so on
      end
    end
    
    # the +delete_metadata+ method deletes 
    # any metadata (with specified attribute names) associated with the passed file
    # === Parameters:
    # * _file_ = a file object which its metadata will be deleted
    # * _attribute_names_ = TODO
    def self.delete_file_metadata(file, attribute_names)
      
      for meta in self.file_metadata_values(file, attribute_names)
        meta_id = meta.id
        # delete the association records
        delete_join_records_for_file(file, meta)
        
        # if this metadata is not linked to any other files, delete it
        # otherwise, leave it
        result = find_files_associated(meta)
        if result.nil?
          meta.destroy
        end
        
      end
    end
    
    #This method is used to delete join records for a spcific file and specific metadata
    def self.delete_join_records_for_file(file, meta)
      attribute = meta.metadata_attribute
      if(attribute.metadata_type == "string")
        Earth::FilesMetadataString.delete_all({:file_id => file.id, :metadata_string_id => meta.id})
        #else if(attribute.metadata_type == "integer")
        # ....Earth::FilesMetadataInteger.delete_all({:file_id => file.id, :metadata_string_id => meta.id})
        # and so on
      end
    end
    
    #This method is used to delete join records for a specific metadata    
    def self.delete_join_records(meta)
      attribute = meta.metadata_attribute
      if(attribute.metadata_type == "string")
        Earth::FilesMetadataString.delete_all({:metadata_string_id => meta.id})
        #else if(attribute.metadata_type == "integer")
        # ....Earth::FilesMetadataInteger.delete_all({:metadata_string_id => meta.id})
        # and so on
      end
    end
    
    # deletes all files_metadata for all files under a directory and its subdirectories
    # ===Parameters:
    # * _dir_ = a directory object which metadata for all files under it will be deleted
    # * _attribute_names_ = TODO 
    def self.delete_all_files_metadata_under_dir(dir, attribute_names)
      if dir.direct_children.size == 0
        delete_list_files_metadata(dir.files, attribute_names)
        return
      end
      
      children = dir.direct_children
      
      for i in 0..children.size-1 do
        delete_all_files_metadata_under_dir(children[i], attribute_names)
      end
    end
    
    # the +delete_metadata+ method deletes any metadata associated with all files in the list
    # === Parameters:
    # * _files_ = list of files. Their metadata will be deleted, one by one using the +delete_file_metadata+ method
    # * _attribute_names_ = TODO  
    def self.delete_list_files_metadata(files, attribute_names = nil)
      for i in 0..files.size-1 do
        if not attribute_names.nil?
          delete_file_metadata(files[i], attribute_names)
        else
          delete_file_metadata_all(files[i])
        end
      end
    end
    
    #this method returns metadata values for a given file and specified attribute names
    def self.file_metadata_values(file, attribute_names)
      result = []
      #retrieve attributes from their names
      attributes = Earth::MetadataAttribute.find(:all, :conditions => "name in " + for_sql(attribute_names)) 
      #now, bring the corrosponding metadata from each attribute linke with the passed file
      for att in attributes do
        if(att.metadata_type == "string")
          values = Earth::MetadataString.find(:all, :conditions => {:metadata_attribute_id => att.id})
          #else if(att.metadata_type =="integer")
          # ....values = Earth::FilesMetadataInteger.find(:all, :conditions => {:metadata_attribute_id => att.id})
          # and so on
        end
        # save the values which are associated with the passed file
        for v in values do
          if search_files(v.files, file.id)
            result << v
          end
        end
      end
      result
    end
    
    #this method returns metadata values for a specified metadata_attributes
    # +attributes+ === array of Earth::MetadataAttribute objects 
    def self.metadata_values(attributes)
      result = []
      #now, bring the corrosponding metadata from each attribute linke with the passed file
      for att in attributes do
        if(att.metadata_type == "string")
          values = Earth::MetadataString.find(:all, :conditions => {:metadata_attribute_id => att.id})
          #else if(att.metadata_type =="integer")
          # ....values = Earth::FilesMetadataInteger.find(:all, :conditions => {:metadata_attribute_id => att.id})
          # and so on
        end
        # save the values 
        for v in values do
          result << v
        end
        
      end
      result
    end
    
    # This method is used to find if there is any associated files with set of metadata
    # note, it does not return list of the associated files
    # it is just used to check if there is any files associated
    # TODO maybe it is better to rename it
    def self.find_files_associated(metadata)
      attribute = metadata.metadata_attribute
      if(attribute.metadata_type == "string")
        result = Earth::FilesMetadataString.find_by_metadata_string_id(metadata.id)
        #else if(attribute.metadata_type == "integer")
        #....result = Earth::FilesMetadataInteger.find_by_metadata_integer_id(metadata.id)
        #and so on
      end
      result
    end
    
    # prepare list of names to be used in sql statement
    def self.for_sql(attribute_names)
      new_att = []
      for att in attribute_names do
        new_att << "\'" + att + "\'"
      end
      "(" + new_att.join(",") + ")"
    end
    
    # this method is used to search for a target file id in list of files
    # returns true if the passed +target_id+ is on the +files+ list
    def self.search_files(files, target_id)
      for f in files do
        if f.id == target_id
          return true
        end
      end
      return false
    end
    
    # this method is used to remove all metadata information for a specific plugin
    # this includes: metadat_attributes, metadata values, metadata join records
    def self.remove_metadata_for_plugin(plugin)
      # first, find all metadata attributes for the plugin
      metadata_attributes = plugin.metadata_attributes
      
      # 1- find metadata_values for all the attributes
      # 2- for each metadat_value: 
      #     a. destroy the columns in the association table
      #     b. destroy the metadata value row itself
      # 3- finally, destroy the metadata attributes
      metadata_values = self.metadata_values(metadata_attributes)
      for meta in metadata_values do
        self.delete_join_records(meta)
        meta.destroy
      end
      
      for attribute in metadata_attributes do
        attribute.destroy
      end
      
    end
    
    # deletes all files_metadata for all files under a directory and its subdirectories
    # all metadata will be deleted
    def self.delete_all_files_metadata_under_dir_all(dir)
      if dir.direct_children.size == 0
        delete_list_files_metadata(dir.files)
        return
      end
      
      children = dir.direct_children
      
      for i in 0..children.size-1 do
        delete_all_files_metadata_under_dir_all(children[i])
      end
    end
    
    #This method will remove any metadata association with the passed file
    def self.delete_file_metadata_all(file)
      Earth::FilesMetadataString.delete_all({:file_id => file.id})
      
      #Earth::FilesMetadataInteger.delete_all({:file_id => file.id})
      #and so on ...
    end
    
    
  end
end
