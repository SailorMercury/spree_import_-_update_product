require "fastercsv"
require 'active_support'
require 'action_controller'
require 'yaml'

class ImportUpdate

	def self.viewCSV
		i=1
		#FasterCSV.foreach("/home/mercury/Documents/testing.csv", :headers => :first_row) {|array|
		#proName=array['brand']+ " " + array['product_type']
		#product = Product.find_by_name(proName) # search for product
		#puts product
		#}
		product=Product.new()
		product.name = "xxx"
		puts product
	end
	
	def self.testing(lol, lolz)
		lol=lol+lolz
		return lol
	end
	
	def self.updateVariant(sku, price, costPrice, weight, height,countOnHand)
		v=Variant.find_by_sku(sku)
		puts "updating existing variant"
		v.price=price
		v.cost_price=costPrice
		v.weight=weight
		v.height=height
		v.count_on_hand=countOnHand
		v.save
	end
	
	def self.addVariant(product, sku, price, costPrice, weight, height,countOnHand, variation, optTypes, optPresent)
		puts "adding new variant"
		v = Variant.create :product => product, :sku => sku, :price => price, :cost_price => costPrice, :weight => weight, :height => height, :count_on_hand => countOnHand
		i=0
		while (i!=optTypes.count)
			v.option_values << OptionValue.find_or_create_by_name(:name=>variation[i],:presentation=>variation[i], :option_type => OptionType.find_or_create_by_name(:name=> optTypes[i], :presentation => optPresent[i]))
			i=i+1
		end
		v.save
	end
	
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
			log("Could not find Category taxonomy, so it was created.", :warn)
		  end

		  taxon = Taxon.find_or_create_by_name_and_parent_id_and_taxonomy_id(
			taxon_name,
			master_taxon.root.id,
			master_taxon.id
		  )

		  product.taxons << taxon if taxon.save
		end
    end
	
	def self.addProduct(proName, price, description, sku, costPrice, weight, height, countOnHand, variation, optTypes, optPresent, productType, brand, model)
				puts "test1"
		product = Product.new()
				puts "test2"
		product.name=proName
				puts "test3"
		product.available_on = DateTime.now - 1.day
				puts "test4"
		product.price = price
				puts "test5"
		product.description = description
		puts "test"
		product.save
		puts "product added"
		
		puts "promodeling"
		proModel = Property.find_or_create_by_name_and_presentation("model", "Model")
        ProductProperty.create :property => proModel, :product => product, :value => model
        puts "promodel success"
        
        addVariant(product, sku, price, costPrice, weight, height,countOnHand, variation, optTypes, optPresent)
        puts "add variant success"
        
        
		puts "taxon-ing"
        associate_taxon('Categories', product_type , product)
        associate_taxon('Brand', brand, product)
        puts "taxon success"
	end
	
	def self.importFrom(path)
		FasterCSV.foreach(path, :headers => :first_row) {|array|
		proName=array['brand']+ " " + array['product_type'] # combine brand and product type to become product name
		product = Product.find_by_name(proName) # search for product
		variation=array['variation'].split(',') #split variation into array
		optTypes=array['option_types'].split(',') #split options types into array
		optPresent=array['option_presentation'].split(',') #split option presentation into array
		
		if product #check if product exist or not
			puts "Existing product, searching for variant"
			if Variant.find_by_sku(array['sku'])
				updateVariant(array['sku'], array['price'], array['cost'], array['weight'], array['height'],array['count_on_hand'])
			else
				addVariant(product, array['sku'], array['price'], array['cost'], array['weight'], array['height'],array['count_on_hand'], variation, optTypes, optPresent)
			end			
		else
			puts "adding new product"
			addProduct(proName, array['price'], array['description'], array['sku'], array['cost'], array['weight'], array['height'], array['count_on_hand'], array['variation'], optTypes, optPresent, array['product_type'], array['brand'], array['model'])
		end

		}

	end

end