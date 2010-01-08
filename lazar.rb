get '/lazar/?' do
	OpenTox::Algorithm::Lazar.new.rdf
end

post '/lazar/?' do # create a model

	halt 404, "Dataset #{params[:dataset_uri]} not found" unless  training_activities = OpenTox::Dataset.find(params[:dataset_uri])
	halt 404, "No feature_uri parameter." unless params[:feature_uri]
	halt 404, "No feature_generation_uri parameter." unless params[:feature_generation_uri]

	# create features
	feature_dataset_uri = OpenTox::Algorithm::Fminer.create_feature_dataset(params)
  puts "feature dataset uri "+feature_dataset_uri.to_s
  
	training_features = OpenTox::Dataset.find(feature_dataset_uri)
	halt 404, "Dataset #{feature_dataset_uri} not found." if training_features.nil?
	features = []
	p_vals = {}
	effects = {}
	fingerprints = {}

  puts "create alg"
  #bbrcs_found = false
  #debug = {}
  
	training_features.data.each do |compound,feats|
    
    #debug[compound] = feats
    
		fingerprints[compound] = [] unless fingerprints[compound]
		feats.each do |f|
			f.each do |feature,value|
        #puts "feature "+feature.to_s
				if feature.match( /BBRC_representative/ )
          fingerprints[compound] << value['smarts']
         # puts "-"
					unless features.include? value['smarts']
            #bbrcs_found = true    
          	features << value['smarts']
          #  puts "."
            #puts "adding model feature: "+value['smarts'].to_s
            p_vals[value['smarts']] = value['p_value'].to_f
						effects[value['smarts']] = value['effect']
					end
				end
		  end
		end
    
	end

  #puts debug.inspect

  raise "no p_values" if p_vals.size==0 

  #raise "no bbrc features found" if bbrcs_found==false
  
	model = {
		:activity_dataset => params[:dataset_uri],
		:feature_dataset => feature_dataset_uri.to_s,
		:endpoint => params[:feature_uri],
		:features => features,
		:p_values => p_vals,
		:effects => effects,
		:fingerprints => fingerprints,
		:activities => training_activities.feature_values(params[:feature_uri])
	}

	#puts model.to_yaml
	OpenTox::Model::Lazar.create(model.to_yaml)#.uri

end
