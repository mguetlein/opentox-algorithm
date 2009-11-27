post '/lazar/?' do # create a model
	
  storage = Redland::MemoryStore.new
  parser = Redland::Parser.new
  serializer = Redland::Serializer.new

	halt 404, "Dataset #{params[:activity_dataset_uri]} not found" unless  OpenTox::Dataset.find(params[:activity_dataset_uri])
	halt 404, "Dataset #{params[:feature_dataset_uri]} not found" unless OpenTox::Dataset.find(params[:feature_dataset_uri])
	activities = Redland::Model.new storage
	features = Redland::Model.new storage
	training_activities = OpenTox::Dataset.find params[:activity_dataset_uri]
	training_features = OpenTox::Dataset.find params[:feature_dataset_uri]
	parser.parse_string_into_model(activities,training_activities,'/')
	parser.parse_string_into_model(features,training_features,'/')
	feature = Redland::Node.new(Redland::Uri.new(File.join(@@config[:services]["opentox-algorithm"],'fminer')))
	p_value = Redland::Node.new(Redland::Uri.new(File.join(@@config[:services]["opentox-algorithm"],'fminer/p_value')))
	effect = Redland::Node.new(Redland::Uri.new(File.join(@@config[:services]["opentox-algorithm"],'fminer/effect')))

	smarts = []
	p_vals = {}
	effects = {}
	fingerprints = {}
	features.triples do |s,p,o|
		s = s.uri.to_s.sub(/^\//,'') 
		case p
		when feature
			fingerprints[s] = [] unless fingerprints[s]
			fingerprints[s] << o.uri.to_s.sub(/^\//,'') 
		when p_value
			sma = s.to_s
			smarts << sma
			p_vals[sma] = o.to_s.to_f
		when effect
			sma = s.to_s
			effects[sma] = o.to_s
		end
	end

	activity_uris = []
	act = {}
	activities.triples do |s,p,o|
		activity_uris << p.uri.to_s
		s = s.uri.to_s
		case o.to_s
		when "true"
			act[s] = true
		when "false"
			act[s] = false
		end
	end

=begin
	activity_uris.uniq!
	if activity_uris.size != 1
		halt 400
		"Dataset #{params[:activity_dataset_uri]} has not exactly one feature."
	end

	id = Dir["models/*"].collect{|models|  File.basename(models,".yaml").to_i}.sort.last
	if id.nil?
		id = 1
	else
		id += 1
	end
=end
	
	model = {
		:endpoint => activity_uris[0],
		:features => smarts,
		:p_values => p_vals,
		:effects => effects,
		:fingerprints => fingerprints,
		:activities => act
	}

	#puts model.to_yaml
	OpenTox::Model::Lazar.create(model.to_yaml).uri

end
