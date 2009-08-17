['rubygems', 'sinatra', 'opentox-ruby-api-wrapper', 'libfminer/fminer'].each do |lib|
	require lib
end

ENV['FMINER_SMARTS'] = 'true'
ENV['FMINER_PVALUES'] = 'true'
@@fminer = Fminer::Fminer.new

post '/?' do

	training_dataset = OpenTox::Dataset.new :uri => params[:dataset_uri]

	compounds = training_dataset.compounds
	endpoint_name = training_dataset.name
	id = 1
	compound_list = []
	compounds.each do |c|
		smiles = c.smiles
		activity_features = training_dataset.features(c)
		activity_features.each do |feature|
			activity = feature.value('classification')
			case activity.to_s
			when 'true'
				compound_list[id] = c
				@@fminer.AddCompound(smiles,id)
				@@fminer.AddActivity(true, id)
			when 'false'
				compound_list[id] = c
				@@fminer.AddCompound(smiles,id)
				@@fminer.AddActivity(false, id)
			end
		end
		id += 1
	end

	@@fminer.SetConsoleOut(false)
	features = []
	# run @@fminer
	(0 .. @@fminer.GetNoRootNodes()-1).each do |j|
		result = @@fminer.MineRoot(j)
	 (0 .. result.size-1).each do |i|
		 features << YAML.load(result[i])[0]
		end
	end

	@@fminer.Reset

	smarts_dataset = OpenTox::Dataset.new(:name => endpoint_name + ' BBRC fragments')

	features.each do |f|
		smarts = f[0]
		p = f[1]
		ids = f[2] + f[3]
		if f[2].size > f[3].size
			effect = 'activating'
		else
			effect = 'deactivating'
		end
		ids.each do |id|
			compound = compound_list[id]
			smarts_feature = OpenTox::Feature.new(:name => smarts, :values => {:p_value => p, :effect => effect})
			smarts_dataset.add(compound,smarts_feature)
		end
	end

	smarts_dataset.close
	smarts_dataset.uri

end
