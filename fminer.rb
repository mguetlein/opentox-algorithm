ENV['FMINER_SMARTS'] = 'true'
ENV['FMINER_PVALUES'] = 'true'
@@fminer = Fminer::Fminer.new

post '/fminer/?' do

	#t =Time.now
	dataset = OpenTox::Dataset.find :uri => params[:dataset_uri]
	feature_dataset = OpenTox::Dataset.create :name => dataset.name + "_BBRC_representatives"
	#task = OpenTox::Task.create(:resource_uri => feature_dataset.uri)
	#Spork.spork do
		#task.start
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
					compound_list[id] = c.uri
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
			results = @@fminer.MineRoot(j)
			results.each do |result|
				features << YAML.load(result)[0]
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
				smarts_features[compound_list[id]] << OpenTox::Feature.new(:name => smarts, :p_value => p, :effect => effect).uri
			end
		end

		#d = Time.now - t
		#t = Time.now
		#puts "# FMINER creates dataset #{d}"
		#File.open("/tmp/features.tmp",'w+') { |f| f.print smarts_features.to_yaml }
		#feature_dataset.add("/tmp/features.tmp")
		feature_dataset.add(smarts_features.to_yaml)
		#d = Time.now - t
		#$stderr.puts "# FMINER finished #{feature_dataset.uri} #{d}"
		puts "# FMINER finished #{feature_dataset.uri}"
		#task.completed
	#end
	#task.uri
	feature_dataset.uri

end
