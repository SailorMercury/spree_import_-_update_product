require "fastercsv"
require 'active_support'
require 'action_controller'
require 'yaml'

class ImportUpdate
	
	#attach image to specific product(argument can be variant as well)
	def self.attach_image(product, image)
		path = "/home/mercury/Projects/becon/public/images/product/" + image
		if File.exists?(path)
			img = Image.create(:attachment => File.open(path), :viewable => product)
			product.images << img if img.save
		else
			puts "image file does not exist"
		end
	end
	
	#update variant variable and save
	def self.update_variant(row)
		v=Variant.find_by_sku(row['sku'])
		puts "updating existing variant"
		v.price=row['price']
		v.cost_price=row['cost']
		v.weight=row['weight']
		v.height=row['height']
		v.count_on_hand=row['count_on_hand']
		v.save
	end
	
	#add variant to product
	def self.add_variant(product, row, variation, option_types, option_presentation)
		puts "adding new variant"
		v = Variant.create :product => product, :sku => row['sku'], :price => row['price'], :cost_price => row['cost'], :weight => row['weight'], :height => row['height'], :count_on_hand => row['count_on_hand']
		i=0
		while (i!=option_types.count)
			option_type = OptionType.find_or_create_by_name(:name=> option_types[i], :presentation => option_presentation[i])
			v.option_values << OptionValue.find_or_create_by_name(:name=>variation[i],:presentation=>variation[i], :option_type => option_type)
			i=i+1
		end
		attach_image(v, row['image'])
		v.save
	end
	
	#associate taxon accordingly for product
	def self.associate_taxon(taxonomy_name, taxon_name, product)
		master_taxon = Taxonomy.find_by_name(taxonomy_name)
		
		#Find all existing taxons and assign them to the product
		existing_taxons = Taxon.find_all_by_name(taxon_name)
		if existing_taxons and !existing_taxons.empty?
		  existing_taxons.each do |taxon|
			product.taxons << taxon
		  end
		else
		  #Create any taxons that don't exist
		  master_taxon = Taxonomy.find_by_name(taxonomy_name)
		  if master_taxon.nil?
			master_taxon = Taxonomy.create(:name => taxonomy_name)
			puts "Could not find Category taxonomy, so it was created."
		  end

		  taxon = Taxon.find_or_create_by_name_and_parent_id_and_taxonomy_id(
			taxon_name,
			master_taxon.root.id,
			master_taxon.id
		  )

		  product.taxons << taxon if taxon.save
		end
    end
	
	#add product to database
	def self.add_product(product_name, row, variation, option_types, option_presentation)
		product = Product.new()
		product.name=product_name
		product.available_on = DateTime.now - 1.day
		product.price = row['price']
		product.description = row['description']
		product.save
		
		proModel = Property.find_or_create_by_name_and_presentation("model", "Model")
        ProductProperty.create :property => proModel, :product => product, :value => row['model']
        
        attach_image(product, row['image'])
        
        add_variant(product, row, variation, option_types, option_presentation)
        
        associate_taxon('Categories', row['product_type'] , product)
        associate_taxon('Brand', row['brand'], product)
	end
	
	#import from path
	def self.import_from(path)
		FasterCSV.foreach(path, :headers => :first_row) {|row|
		product_name=row['brand']+ " " + row['product_type'] # combine brand and product type to become product name
		product = Product.find_by_name(product_name) # search for product
		
		variation=row['variation'].split(',') #split variation into row
		option_types=row['option_types'].split(',') #split options types into row
		option_presentation=row['option_presentation'].split(',') #split option presentation into row
		
		if product #check if product exist or not
			puts "Existing product, searching for variant"
			if Variant.find_by_sku(row['sku'])
				update_variant(row)
			else
				add_variant(product, row, variation, option_types, option_presentation)
			end			
		else
			puts "adding new product"
			add_product(product_name, row, variation, option_types, option_presentation)
		end

		}

	end

end
