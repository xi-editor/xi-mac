# Generator to add relative path to root to every page/collection doc with the key rel_root
#
# Example Usage: <img src="{{ page.rel_root }}/image/icon.png">

module PageRelRoot
	class Generator < Jekyll::Generator
		
		def generate(site)
			pages = site.pages + site.collections.flat_map{ |k,v| v.docs }
			pages.each do |page|
				depth = page.url.split("/", -1).count - 2
				page.data['rel_root'] = depth > 0 ? ".." + "/.."*(depth-1) : "."
			end
		end
	end
end
