get '/lazar/?' do
	OpenTox::Algorithm::Lazar.new.rdf
end

post '/lazar/?' do # create a model

	halt 404, "Dataset #{params[:dataset_uri]} not found" unless  training_activities = OpenTox::Dataset.find(params[:dataset_uri])

	# create features
	feature_dataset_uri = RestClient.post params[:feature_generation_uri], :dataset_uri => params[:dataset_uri], :feature_uri => params[:feature_uri] 
	training_features = OpenTox::Dataset.find(feature_dataset_uri)
	halt 404, "Dataset #{feature_dataset_uri} not found." if training_features.nil?
	features = []
	p_vals = {}
	effects = {}
	fingerprints = {}
	training_features.tuples.each do |t|
		features << t[:smarts]
		p_vals[t[:smarts]] = t[:p_value]
		effects[t[:smarts]] = t[:effect]
		t[:compounds].each do |c|
			fingerprints[c] = [] unless fingerprints[c]
			fingerprints[c] << t[:smarts]
		end
	end
	
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

	#model.to_yaml
	OpenTox::Model::Lazar.create(model.to_yaml)#.uri

end
