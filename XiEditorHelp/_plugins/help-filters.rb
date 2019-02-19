module Jekyll
	module HelpFilters
		
		# These filters are modified version of Jekyll's where and group_by filters
		
		# Filter an array of objects by the existence of a property
		#
		# input - the object array
		# property - property to existence-test within each object
		#
		# Returns the filtered array of objects
		def has(input, property)
			return input unless input.is_a?(Enumerable)
			input = input.values if input.is_a?(Hash)
			input.select { |object| item_property(object, property) != nil }
		end

		# Tree-group an array of items by a property, and add a looked-up property to each group
		# (this seems all a bit kludgy -- there must be a more principled way to do this...)
		#
		# input - the inputted Enumerable
		# property - the property
		# newprop - new property name to set on groups
		# lookup - hash map from group names to value for setting newprop
		#
		# Returns an array of items (which didn't have property) and group hashes (of items that share the named property)
		def tree_by_with_prop_lookup(input, property, newprop, lookup)
			if groupable?(input)
				input.group_by do |item|
					item_property(item, property).to_s
				end.inject([]) do |memo, i|
					if i.first == ""
						memo + i.last
						else
						memo << {"name" => i.first, "items" => i.last, newprop => (lookup[i.first] || 0) }
					end
				end
				else
				input
			end
		end

		# Stable Sort an array of objects
		#
		# input - the object array
		# property - property within each object to filter by
		#
		# Returns the filtered array of objects
		def stable_sort(input, property = nil)
			if input.nil?
				raise ArgumentError.new("Cannot sort a null object.")
			end
			if property.nil?
				raise ArgumentError.new("Cannot sort without property.")
			end
			input.sort_by.with_index { |e, index| [item_property(e, property), index] }
		end
		
	end
end

Liquid::Template.register_filter(Jekyll::HelpFilters)