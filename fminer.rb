ENV['FMINER_SMARTS'] = 'true'
ENV['FMINER_PVALUES'] = 'true'
@@fminer = Fminer::Fminer.new

post '/fminer/?' do

	#storage = Redland::MemoryStore.new
	parser = Redland::Parser.new

	training_data = Redland::Model.new Redland::MemoryStore.new
	feature_data = Redland::Model.new Redland::MemoryStore.new

	dataset = OpenTox::Dataset.find params[:dataset_uri]
	parser.parse_string_into_model(training_data,dataset,'/')
	feature = Redland::Uri.new params[:feature_uri]

	id = 1
	compound_list = []
	training_data.find(nil,feature,nil) do |c,f,v|
		compound = OpenTox::Compound.new(:uri => c.to_s)
		smiles = compound.smiles
		if v.to_s == "true"
			compound_list[id] = c
			@@fminer.AddCompound(smiles,id)
			@@fminer.AddActivity(true, id)
		elsif v.to_s == "false"
			compound_list[id] = c
			@@fminer.AddCompound(smiles,id)
			@@fminer.AddActivity(false, id)
		end
		id += 1
	end

	@@fminer.SetConsoleOut(false)
	@@fminer.SetChisqSig(0.95)
	features = ""
	# run @@fminer
	(0 .. @@fminer.GetNoRootNodes()-1).each do |j|
		results = @@fminer.MineRoot(j)
		results.each do |result|
			f = YAML.load(result)[0]
			feature = Redland::Uri.new(f[0]) # smarts
			p_value = Redland::Uri.new(url_for('/fminer/p_value', :full))
			feature_data.add(feature, p_value, Redland::Literal.new(f[1].to_s)) # p_value
			ids = f[2] + f[3]
			if f[2].size > f[3].size
				effect = 'activating'
			else
				effect = 'deactivating'
			end
			eff = Redland::Uri.new(url_for('/fminer/effect', :full))
			feature_data.add(feature, eff, Redland::Literal.new(effect))
			#puts "#{f[0]}\t#{f[1]}\t#{effect}"
			ids.each do |id|
				feature_data.add(compound_list[id], Redland::Uri.new(url_for('/fminer',:full)), feature)
			end
		end
	end

	@@fminer.Reset

	OpenTox::Dataset.create(feature_data.to_string).uri

end
