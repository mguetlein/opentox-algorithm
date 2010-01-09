ENV['FMINER_SMARTS'] = 'true'
ENV['FMINER_PVALUES'] = 'true'
@@fminer = Fminer::Fminer.new

get '/fminer/?' do
	OpenTox::Algorithm::Fminer.new.rdf
end

post '/fminer/?' do

	feature_uri = params[:feature_uri]
	halt 404, "Please submit a feature_uri parameter." if feature_uri.nil?
	training_dataset = OpenTox::Dataset.find params[:dataset_uri] 
	halt 404, "Dataset #{params[:dataset_uri]} not found." if training_dataset.nil? 

	task = OpenTox::Task.create

	#pid = fork do
	Spork.spork(:logger => LOGGER) do

		task.start

		feature_dataset = OpenTox::Dataset.new
		title = "BBRC representatives for " + training_dataset.title
		feature_dataset.title = title
		feature_dataset.source = url_for('/fminer',:full)
		bbrc_uri = url_for("/fminer#BBRC_representative",:full)
		bbrc_feature = feature_dataset.find_or_create_feature bbrc_uri

		id = 1 # fminer start id is not 0
		compounds = []
		@@fminer.Reset
		training_dataset.feature_values(feature_uri).each do |c,f|
			smiles = OpenTox::Compound.new(:uri => c.to_s).smiles
			compound = feature_dataset.find_or_create_compound(c.to_s)
			puts "No #{feature_uri} for #{c.to_s}." if f.size == 0
			f.each do |act|
				#puts act
				case act.to_s
				when "true"
					#puts smiles + "\t" + true.to_s
					compounds[id] = compound
					@@fminer.AddCompound(smiles,id)
					@@fminer.AddActivity(true, id)
				when "false"
					#puts smiles + "\t" + false.to_s
					compounds[id] = compound
					@@fminer.AddCompound(smiles,id)
					@@fminer.AddActivity(false, id)
				end
			end
			id += 1
		end

		@@fminer.SetConsoleOut(false)
		@@fminer.SetChisqSig(0.95)
		values = {}
		# run @@fminer
		(0 .. @@fminer.GetNoRootNodes()-1).each do |j|
			results = @@fminer.MineRoot(j)
			results.each do |result|
				f = YAML.load(result)[0]
				smarts = f[0]
				p_value = f[1]
				ids = f[2] + f[3]
				if f[2].size > f[3].size
					effect = 'activating'
				else
					effect = 'deactivating'
				end
				tuple = feature_dataset.create_tuple(bbrc_feature,{ url_for('/fminer#smarts',:full) => smarts, url_for('/fminer#p_value',:full) => p_value, url_for('/fminer#effect',:full) => effect })
				#puts "#{f[0]}\t#{f[1]}\t#{effect}"
				ids.each do |id|
					feature_dataset.add_tuple compounds[id], tuple
				end
			end
		end

		uri = feature_dataset.save # does not return
		task.completed(uri)
	end
	#Process.detach(pid)
	task.uri

end
