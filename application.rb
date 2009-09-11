require 'rubygems'
require 'sinatra'
require 'libfminer/fminer'
require 'opentox-ruby-api-wrapper'

ENV['FMINER_SMARTS'] = 'true'
ENV['FMINER_PVALUES'] = 'true'
@@fminer = Fminer::Fminer.new

post '/?' do

	dataset = OpenTox::Dataset.find :uri => params[:dataset_uri]
	id = 1
	compound_list = []
	dataset.compounds.each do |c|
		activities = dataset.features(c)
		smiles = c.smiles
		activities.each do |feature|
			activity = feature.value('classification')
			case activity.to_s
			when 'true'
				compound_list[id] = c.uri
				@@fminer.AddCompound(smiles,id)
				@@fminer.AddActivity(true, id)
			when 'false'
				compound_list[id] = c.inchi
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

	smarts_features = {}
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
			smarts_features[compound_list[id]] = [] unless smarts_features[compound_list[id]]
			smarts_features[compound_list[id]] << OpenTox::Feature.new(:name => smarts, :values => {:p_value => p, :effect => effect}).uri
		end
	end

	feature_dataset = OpenTox::Dataset.create :name => dataset.name + "_BBRC_representatives"
	feature_dataset.add(smarts_features)
	feature_dataset.uri

end
