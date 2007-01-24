
# FasterNestedSet

require 'active_record'
require 'thread'

#
#  This is another nested set implementation for RoR.  Its main
#  advantage over existing implementations is that it allows for
#  deferred inserts (large subtrees can be inserted in one go where
#  other implementations incur a full table update for each individual
#  inserted node), a more natural API (there's no need to pay
#  attention to outdated left/right values in nodes), and that it only 
#  uses one update statement per insertion/deletion/move operation 
#  instead of two.
# 
#  This implementation aims to be largely compatible to tree and
#  nested_set (the default implementations shipping with RoR) as well
#  as better_nested_set
#  (http://opensource.symetrie.com/trac/better_nested_set/).
#
#  - the acts_as_nested_set declaration's configuration is
#    compatible to the acts_as_nested_set declaration: the
#    parent_column, left_column, right_column and scope options are
#    supported and semantically identical.
#
#  - nested_set's children_count(), full_set(), all_children(),
#    direct_children(), root?() and child?() methods are supported and
#    semantically identical.  add_child() is supported as well but
#    deprecated (see below.)
#
#  Adding children shouldn't be handled as in nested_set (using the
#  add_child method) but as in tree, that is using
#  parent.children.create or parent.children.build, where the latter
#  will not commit the added child to the database immediately.  This
#  allows for building subtrees in memory and committing them to the
#  database in one go.  For large subtrees inserted in a deferred
#  manner, this reduces the O(n+n^2) complexity of an insert found in
#  the nested_set and better_nested_set implementations (one insert
#  for each new node plus two full-table updates for each new row
#  affecting on average half of the rows) to O(n) complexity (one
#  insert for each row plus two full-table updates total).  Note that
#  the add_child() method found in the default nested_set
#  implementation is supported for compatibility reasons but should be
#  avoided in favor of the tree interface.
#
#  This implementation tries to do "the right thing" when possible.
#  For instance, you shouldn't ever have to worry about outdated
#  nodes.
#
#  Suggested table layout (for PostgreSQL):
#
#  create table example_nodes (
#     id         serial   primary key,
#     parent_id  integer  null references example_nodes(id),
#     lft        integer  not null,
#     rgt        integer  not null,
#     scope      integer  not null,
#     ...
#     constraint unique_lft unique (scope, lft),
#     constraint unique_rgt unique (scope, rgt),
#     constraint valid_lft_rgt check (left > 0 and right > left)
#  );
#
#  Notes with regard to the table layout: 
# 
#  - parent_id, lft and rgt are column names inherited from the
#    default nested_set implementation.  Personally, the author would
#    use the names parent_id, left_edge and right_edge.  If you choose
#    different names you'll have to specify the corresponding
#    configuration options (:parent_column, :left_column, and
#    :right_column, resp.).
#
#  - The parent_id column must be nullable since a root node has no
#    parent.  It should have a foreign key constraint so that all
#    non-root nodes are guaranteed to have a valid parent.
#    Unfortunately, there doesn't appear to be a constraint that could
#    be used to make sure that there's only one root node per scope.
#
#  - You can have a scope discriminator for storing more than one
#    distinct, non-overlapping tree in the same table.  In this
#    example, an integer is used but in real life it's more likely to
#    be a reference to another table.  This column should usually be
#    declared not null since every node is in a particular scope.
#    Note that the scope condition must be configured explicitly using
#    the :scope option.
#
#  - The left and right values can (and should) be declared unique
#    within each scope as shown in the example - this implementation
#    will update existing values before inserting new entries so that
#    this condition will not be violated unless there's an internal
#    problem.  
#
#    Ideally, you would specify a constraint that makes sure that the
#    union of the values in both left and right is unique - in other
#    words, a constraint that makes sure that there is no left value
#    that matches a right value in the same or any other row, and vice
#    versa.  Unfortunately, to the knowledge of the author there is no
#    such constraint type in any database product.  The unique(lft,
#    rgt) constraint might appear to serve that purpose but instead it
#    means that every combination of lft and rgt needs to be unique
#    (and thus is weaker than defining each of the two columns unique
#    individually.)
#
#    You can (and should) have an additional constraint in place that
#    makes sure that the left and right values are positive, and that
#    the right value is always greater than the left value, as shown
#    in the example.

module Rsp
  module Acts #:nodoc:
    module FasterNestedSet #:nodoc:
      module ChildrenExtension #:nodoc:
        def build(attributes)
          result = super
          @node.child_added(result)
          result.parent_assoc = @node
          result
        end

        def node=(node)
          @node = node
        end
        
        def add_to_cache(child)
          @target << child
        end
        def empty_cache
          @target = []
        end
      end

      def self.included(mod)
        mod.extend(ClassMethods)
      end

      # declare the class level helper methods which
      # will load the relevant instance methods
      # defined below when invoked
      module ClassMethods
        def acts_as_nested_set(options=nil)

          before_save("self.nested_set_before_save; true")
          after_save("self.nested_set_after_save; true")
          before_destroy("self.nested_set_before_destroy; true")
          after_destroy("self.nested_set_after_destroy; true")

          # --- Below this point taken verbose from tree.rb --- #

          configuration = { :foreign_key => "parent_id", :order => nil, :counter_cache => nil, :left_column => "lft", :right_column => "rgt", :scope => "1 = 1" , :text_column => nil, :level_column => nil}
          configuration.update(options) if options.is_a?(Hash)

          configuration[:scope] = "#{configuration[:scope]}_id".intern if configuration[:scope].is_a?(Symbol) && configuration[:scope].to_s !~ /_id$/

          if configuration[:scope].is_a?(Symbol)
            scope_condition_method = %(
              def scope_condition
                if #{configuration[:scope].to_s}.nil?
                  "#{table_name}.#{configuration[:scope].to_s} IS NULL"
                else
                  "#{table_name}.#{configuration[:scope].to_s} = \#{#{configuration[:scope].to_s}}"
                end
              end
            )
          else
            scope_condition_method = "def scope_condition() \"#{configuration[:scope]}\" end"
          end

          belongs_to :parent_assoc, :class_name => name, :foreign_key => configuration[:foreign_key], :counter_cache => configuration[:counter_cache]

          has_many :children, :class_name => name, :foreign_key => configuration[:foreign_key], :order => configuration[:order], :dependent => :destroy, :extend => Rsp::Acts::FasterNestedSet::ChildrenExtension

          class_eval <<-EOV
            #{scope_condition_method}

            def left_col_name() "#{configuration[:left_column]}" end

            def right_col_name() "#{configuration[:right_column]}" end

            def level_col_name() "#{configuration[:level_column]}" end

            def has_level_column?() #{not configuration[:level_column].nil?} end

            def parent_col_name() "#{configuration[:foreign_key]}" end

            def parent_column() "#{configuration[:foreign_key]}" end

            def self.roots
              find(:all, 
                   :conditions => "#{configuration[:foreign_key]} IS NULL", 
                   :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
            end

            def self.root
              find(:first, 
                   :conditions => "#{configuration[:foreign_key]} IS NULL", 
                   :order => #{configuration[:order].nil? ? "nil" : %Q{"#{configuration[:order]}"}})
            end
          EOV

          include Rsp::Acts::FasterNestedSet::InstanceMethods
        end
      end

      # Adds instance methods.
      module InstanceMethods

        def initialize(attributes)
          if (not attributes.nil?) and (attributes.has_key?(:parent) or attributes.has_key?(parent_column)) then
            raise "Do not specify parent value on initialization; instead, use parent.children.build or parent.children.create"
          end
          super
        end

        def parent=(_parent)
          prev_parent = self.parent_assoc
          if not prev_parent.nil?

            prev_parent_lft = prev_parent[left_col_name]
            prev_parent_rgt = prev_parent[right_col_name]
            prev_parent_id  = prev_parent.id

            self.parent_assoc = _parent
            _parent.child_added(self)

            if _parent[left_col_name] > prev_parent_lft then
              node_new_right = _parent[right_col_name] - 1
            else
              node_new_right = _parent[right_col_name] + (self[right_col_name] - self[left_col_name])
            end
            node_new_left = node_new_right - (self[right_col_name] - self[left_col_name])

            moved_subtree_left_inclusive = self[left_col_name]
            moved_subtree_right_inclusive = self[right_col_name]
            moved_subtree_offset = node_new_left - self[left_col_name]

            if _parent[left_col_name] > prev_parent_lft then
              interior_subtree_left_inclusive = self[right_col_name] + 1
              interior_subtree_right_inclusive = node_new_right
              interior_subtree_offset = - (self[right_col_name] - self[left_col_name] + 1)
            else
              interior_subtree_left_inclusive = node_new_left
              interior_subtree_right_inclusive = self[left_col_name] - 1
              interior_subtree_offset = (self[right_col_name] - self[left_col_name] + 1)
            end

            self.class.update_all( "#{left_col_name} = #{left_col_name} + (CASE WHEN #{left_col_name} >= #{moved_subtree_left_inclusive} AND #{left_col_name} <= #{moved_subtree_right_inclusive} THEN #{moved_subtree_offset} WHEN #{left_col_name} >= #{interior_subtree_left_inclusive} AND #{left_col_name} <= #{interior_subtree_right_inclusive} THEN #{interior_subtree_offset} ELSE 0 END), #{right_col_name} = #{right_col_name} + (CASE WHEN #{right_col_name} >= #{moved_subtree_left_inclusive} AND #{right_col_name} <= #{moved_subtree_right_inclusive} THEN #{moved_subtree_offset} WHEN #{right_col_name} >= #{interior_subtree_left_inclusive} AND #{right_col_name} <= #{interior_subtree_right_inclusive} THEN #{interior_subtree_offset} ELSE 0 END)",  
                                   "#{scope_condition} AND ((#{right_col_name} >= #{moved_subtree_left_inclusive} AND #{left_col_name} <= #{moved_subtree_right_inclusive}) OR (#{right_col_name} >= #{interior_subtree_left_inclusive} AND #{left_col_name} <= #{interior_subtree_right_inclusive}))" )

          else
            self.parent_assoc = _parent
            _parent.child_added(self)
          end
        end

        def parent
          self.parent_assoc || @parent_internal
        end

        def has_parent?
          not self.parent.nil?
        end

        def after_initialize
          self.children.node = self
        end

        def after_find
          self.children.node = self
        end

        def reload
          result = super
          self.children.node = self
          result
        end

        def parent_internal=(parent)
          @parent_internal = parent
        end

        def child_added(node)
          node.parent_internal = self
          if not self.new_record? then
            self.add_dirty_child(node)
          end
        end

        def dirty= (val)
          @dirty = true
        end

        def add_dirty_child(child)
          if true
            found = false
            self.children.each_index do |index|
              if self.children[index].id == child.id then
                self.children[index] = child
                found = true
              end
            end
            if not found
              self.children << child
            end
          end
          child.dirty = true
          if @parent_internal then
            @parent_internal.add_dirty_child(self)
          else
            self.dirty = true
          end
        end

        def nested_set_before_destroy
          if Thread.current["root_deleted_node"].nil?
            Thread.current["root_deleted_node"] = self
          end

          @children.each do |child|
            child.destroy
          end
        end

        def nested_set_after_destroy

          if Thread.current["root_deleted_node"] == self
            Thread.current["root_deleted_node"] = nil

            offset = self[right_col_name] - self[left_col_name] + 1
            self.class.update_all( "#{left_col_name} = #{left_col_name} - (CASE WHEN #{left_col_name} > #{self[right_col_name]} THEN #{offset} ELSE 0 END), #{right_col_name} = #{right_col_name} - (CASE WHEN #{right_col_name} > #{self[right_col_name]} THEN #{offset} ELSE 0 END)",  
                                   "#{scope_condition} AND #{right_col_name} > #{self[right_col_name]}" )
          end
        end

        def update_edge_data(left, level)
          self[left_col_name] = left
          self[level_col_name] = level unless not has_level_column?
          child_left = left + 1
          child_right = child_left
          if @children
            @children.each do |child| 
              child_right = child.update_edge_data(child_left, level + 1) + 1
              child_left = child_right
            end
          end
          right = child_right
          self[right_col_name] = right
          right
        end

        def nested_set_after_save
          if Thread.current["saved_node"] == self
            Thread.current["saved_node"] = nil
          end
          
          @dirty = false

          if Thread.current["unsaved_children"] then
            unsaved_children = Thread.current["unsaved_children"]
            Thread.current["unsaved_children"] = []
            unsaved_children.each do |unsaved_child| 
              unsaved_child.save
            end
          end
          
        end

        def dirty?
          @dirty
        end

        def nested_set_before_save
          if @new_record or @save_required then
            self.nested_set_before_save_new_record
          elsif @dirty then
            self.nested_set_before_save_dirty_record
          end
        end

        def nested_set_before_save_dirty_record
          if @dirty and self.children.loaded then
            self.children.each do |child| 
              if child.dirty?
                if child.new_record? or child.save_required?
                  Thread.current["unsaved_children"] = [child] + (Thread.current["unsaved_children"] || [])
                else
                  child.nested_set_before_save_dirty_record
                end
              end
            end
          end          
        end

        def nested_set_before_save_new_record
          
          if Thread.current["saved_node"].nil?
            Thread.current["saved_node"] = self

            if self.parent_assoc.nil?
              left = 1
              level = 1
            else
              left = self.parent_assoc[right_col_name] 
              #left = self.parent_assoc[left_col_name + 1] 
              if has_level_column?
                level = self.parent_assoc[level_col_name] + 1
              end
            end

            right = self.update_edge_data(left, level)

            if not self.parent_assoc.nil?
              offset = 2 
              self.class.update_all( "#{left_col_name} = #{left_col_name} + (CASE WHEN #{left_col_name} >= #{left} THEN #{offset} ELSE 0 END), #{right_col_name} = #{right_col_name} + (CASE WHEN #{right_col_name} >= #{left} THEN #{offset} ELSE 0 END)",  
                                     "#{scope_condition} AND #{right_col_name} >= #{left}" )
              self.parent_assoc[right_col_name] += offset
            end
          end
        end

        # --- Below this point taken verbose from tree.rb --- #

        # Returns list of ancestors, starting from parent until root.
        #
        #   subchild1.ancestors # => [child1, root]
        def ancestors
          node, nodes = self, []
          nodes << node = node.parent until not node.has_parent?
          nodes
        end

        def root
          node = self
          node = node.parent until not node.has_parent?
          node
        end

        def siblings
          self_and_siblings - [self]
        end

        def self_and_siblings
          has_parent? ? parent.children : self.class.roots
        end

        # --- Above this point taken verbose from tree.rb --- #

        # --- Below this point taken verbose from nested_set.rb --- #

        # Returns the number of nested children of this object.
        def children_count
          return (self[right_col_name] - self[left_col_name] - 1)/2
        end
                                                               
        # Returns a set of itself and all of its nested children
        def full_set
          self.class.base_class.find(:all, :conditions => "#{scope_condition} AND (#{left_col_name} BETWEEN #{self[left_col_name]} and #{self[right_col_name]})" )
        end
                  
        # Returns a set of all of its children and nested children
        def all_children
          self.class.base_class.find(:all, :conditions => "#{scope_condition} AND (#{left_col_name} > #{self[left_col_name]}) and (#{right_col_name} < #{self[right_col_name]})" )
        end
                                  
        # Returns a set of only this entry's immediate children
        def direct_children
          self.class.base_class.find(:all, :conditions => "#{scope_condition} and #{parent_column} = #{self.id}")
        end

        # Returns true is this is a root node.  
        def root?
          parent_id = self[parent_column]
          (parent_id == 0 || parent_id.nil?) && (self[left_col_name] == 1) && (self[right_col_name] > self[left_col_name])
        end                                                                                             
                                    
        # Returns true is this is a child node
        def child?                          
          parent_id = self[parent_column]
          !(parent_id == 0 || parent_id.nil?) && (self[left_col_name] > 1) && (self[right_col_name] > self[left_col_name])
        end     
        
        # Returns true if we have no idea what this is
        def unknown?
          !root? && !child?
        end

        # --- Above this point taken verbose from nested_set.rb --- #

        # --- Below this point taken verbose from better_nested_set.rb --- #
        
        # Returns the array of all parents and self
        def self_and_ancestors
          [self] + ancestors
        end

        # --- Above this point taken verbose from better_nested_set.rb --- #

        def save_required?
          @save_required
        end

        def save_required= (val)
          @save_required = val
        end

        def add_child(child)
          self.children << child
          child.save
        end

        def parent_assigned(*args)
          self.save_required = true
          parent_assoc.child_added(self)
        end

        def child_create(attributes)
          children.create(attributes)
        end

        def child_delete(child)
          children.delete(child)
        end

        # Override the default implementation of update to write all attributes except
        # lft and rgt
        def update
          newchildren = children.count { |child| child.new_record? }
          if not self.new_record?
            a = attributes_with_quotes(false)
            a.delete(left_col_name)
            a.delete(right_col_name)
            connection.update(
                              "UPDATE #{self.class.table_name} " +
                                                                  "SET #{quoted_comma_pair_list(connection, a)} " +
                                                                  "WHERE #{self.class.primary_key} = #{id}",
                              "#{self.class.name} Update"
                              )
            return true
          else
            super
          end
        end

        def load_all_children(depth=0, options=nil)
          
          if depth == 0 or not has_level_column?
            depth_condition = "1=1"
          else
            depth_condition = "#{self.class.table_name}.#{level_col_name} <= #{level + depth}"
            end
          
          options = options || Hash.new

          options[:conditions] = "#{depth_condition} AND #{scope_condition} AND (#{self.class.table_name}.#{left_col_name} > #{self[left_col_name]}) and (#{self.class.table_name}.#{right_col_name} < #{self[right_col_name]})"
          options[:order] = self.class.table_name + "." +left_col_name

          result = self.class.find(:all, options)

          idMap = Hash.new
          result.each do |child|
            idMap[child[:id]] = child
          end

          idMap[self.id] = self
          self.children.empty_cache

          result.each do |child|
            idMap[child[:parent_id]].children.add_to_cache(child) unless child[:parent_id].nil?
            child.parent_assoc = idMap[child[:parent_id]]
          end

          idMap.each do |key, child|
            child.children.loaded
          end
        end
      end
    end
  end
end

# reopen ActiveRecord and include all the above to make
# them available to all our models if they want it

ActiveRecord::Base.class_eval do
  include Rsp::Acts::FasterNestedSet
end
