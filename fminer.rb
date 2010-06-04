ENV['FMINER_SMARTS'] = 'true'
ENV['FMINER_PVALUES'] = 'true'
@@fminer = Fminer::Fminer.new 
@@fminer.SetAromatic(true)

get '/fminer/?' do
	if File.exists?('public/fminer.owl')
		rdf = File.read('public/fminer.owl')
	else
		owl = OpenTox::Owl.create 'Algorithm', url_for('/fminer',:full)
		owl.set 'title',"fminer"
		owl.set 'creator',"http://github.com/amaunz/libfminer"
		owl.parameters = {
			"Dataset URI" => { :scope => "mandatory", :value => "dataset_uri" },
			"Feature URI for dependent variable" => { :scope => "mandatory", :value => "feature_uri" }
		}
		rdf = owl.rdf
		File.open('public/fminer.owl', 'w') {|f| f.print rdf}
	end
	response['Content-Type'] = 'application/rdf+xml'
	rdf
end

post '/fminer/?' do

	halt 404, "Please submit a dataset_uri." unless params[:dataset_uri] and  !params[:dataset_uri].nil?
	halt 404, "Please submit a feature_uri." unless params[:feature_uri] and  !params[:feature_uri].nil?
	LOGGER.debug "Dataset: " + params[:dataset_uri]
	LOGGER.debug "Endpoint: " + params[:feature_uri]
	feature_uri = params[:feature_uri]
	begin
		LOGGER.debug "Retrieving #{params[:dataset_uri]}"
		training_dataset = OpenTox::Dataset.find "#{params[:dataset_uri]}"
		#LOGGER.debug training_dataset.to_yaml
	rescue
		LOGGER.error "Dataset #{params[:dataset_uri]} not found" 
		halt 404, "Dataset #{params[:dataset_uri]} not found." if training_dataset.nil? 
	end
	halt 404, "No feature #{params[:feature_uri]} in dataset #{params[:dataset_uri]}" unless training_dataset.features and training_dataset.features.include?(params[:feature_uri])

  task_uri = OpenTox::Task.as_task do 

		feature_dataset = OpenTox::Dataset.new
		title = "BBRC representatives for " + training_dataset.title
		feature_dataset.title = title
		feature_dataset.creator = url_for('/fminer',:full)
		bbrc_uri = url_for("/fminer#BBRC_representative",:full)
		feature_dataset.features << bbrc_uri

		id = 1 # fminer start id is not 0
		compounds = []

		@@fminer.Reset
		LOGGER.debug "Fminer: initialising ..."
		training_dataset.data.each do |c,features|
			begin
				smiles = OpenTox::Compound.new(:uri => c.to_s).smiles
			rescue
				LOGGER.warn "No resource for #{c.to_s}"
				next
			end
			if smiles == '' or smiles.nil?
				LOGGER.warn "Cannot find smiles for #{c.to_s}."
			else
				feature_dataset.compounds << c.to_s
				features.each do |feature|
					act = feature[feature_uri]
					if act.nil? 
						LOGGER.warn "No #{feature_uri} activiity for #{c.to_s}."
					else
						case act.to_s
						when "true"
							#LOGGER.debug id.to_s + ' "' + smiles +'"' +  "\t" + true.to_s
							activity = 1
						when "false"
							#LOGGER.debug id.to_s + ' "' + smiles +'"' +  "\t" + false.to_s
							activity = 0
						else
							# AM: add quantitative activity
							activity = act.to_f
							@@fminer.SetRegression(true)
							Logger.debug "Activity '" + act.to_s + "' switches fminer to regression".
						end
						compounds[id] = c.to_s
						begin
							@@fminer.AddCompound(smiles,id)
							@@fminer.AddActivity(activity, id)
						rescue
							LOGGER.warn "Could not add " + smiles + "\t" + activity + " to fminer"
						end
					end
				end
				id += 1
			end
		end
		minfreq = (0.06*id).round
		@@fminer.SetMinfreq(minfreq)
		LOGGER.debug "Fminer: initialised with #{id} compounds, minimum frequency #{minfreq}"

    raise "no compounds" if compounds.size==0

		values = {}
		# run @@fminer
		LOGGER.debug "Fminer: mining ..."
		(0 .. @@fminer.GetNoRootNodes()-1).each do |j|
			results = @@fminer.MineRoot(j)
			results.each do |result|
				f = YAML.load(result)[0]
				smarts = f[0]
				p_value = f[1]
				# AM: f[3] missing on regression
				if (!@@fminer.GetRegression) 
					ids = f[2] + f[3]
					if f[2].size > f[3].size
						effect = 'activating'
					else
						effect = 'deactivating'
					end
				else
					ids = f[2]
					effect = 'activating' # AM: Pending: needs analysis of median act
				end

				tuple = { url_for('/fminer#smarts',:full) => smarts, url_for('/fminer#p_value',:full) => p_value.to_f, url_for('/fminer#effect',:full) => effect }
				#LOGGER.debug "#{f[0]}\t#{f[1]}\t#{effect}"
				ids.each do |id|
					feature_dataset.data[compounds[id]] = [] unless feature_dataset.data[compounds[id]]
					feature_dataset.data[compounds[id]] << {bbrc_uri => tuple}
				end
			end
		end

		# this takes too long for large datasets
		uri = feature_dataset.save 
		LOGGER.debug "Fminer finished, dataset #{uri} created."
    uri
	end
	LOGGER.debug "Fimer task started: "+task_uri.to_s
	response['Content-Type'] = 'text/uri-list'
	halt 202,task_uri.to_s+"\n"
end
