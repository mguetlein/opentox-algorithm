ENV['FMINER_SMARTS'] = 'true'
ENV['FMINER_NO_AROMATIC'] = 'true'
ENV['FMINER_PVALUES'] = 'true'
@@fminer = Bbrc::Bbrc.new 

get '/fminer/?' do
  owl = OpenTox::Owl.create 'Algorithm', url_for('/fminer',:full)
  owl.set 'title',"fminer"
  owl.set 'creator',"http://github.com/amaunz/fminer2"
  owl.parameters = {
    "Dataset URI" => { :scope => "mandatory", :value => "dataset_uri" },
    "Feature URI for dependent variable" => { :scope => "mandatory", :value => "feature_uri" }
  }
  rdf = owl.rdf
  File.open('public/fminer.owl', 'w') {|f| f.print rdf}
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
	rescue
		LOGGER.error "Dataset #{params[:dataset_uri]} not found" 
		halt 404, "Dataset #{params[:dataset_uri]} not found." if training_dataset.nil? 
	end
	halt 404, "No feature #{params[:feature_uri]} in dataset #{params[:dataset_uri]}" unless training_dataset.features and training_dataset.features.include?(params[:feature_uri])

  task_uri = OpenTox::Task.as_task("Mine features", url_for('/fminer',:full)) do 

		feature_dataset = OpenTox::Dataset.new
		title = "BBRC representatives for " + training_dataset.title
		feature_dataset.title = title
		feature_dataset.creator = url_for('/fminer',:full)
		feature_dataset.token_id = params[:token_id] if params[:token_id]
		feature_dataset.token_id = CGI.unescape(request.env["HTTP_TOKEN_ID"]) if !feature_dataset.token_id and request.env["HTTP_TOKEN_ID"]
		
		bbrc_uri = url_for("/fminer#BBRC_representative",:full)
		feature_dataset.features << bbrc_uri

		id = 1 # fminer start id is not 0
		compounds = []

    g_hash = Hash.new# DV: for effect calculation in regression part
		@@fminer.Reset
    #@@fminer.SetChisqSig(0.99)
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
						end
						compounds[id] = c.to_s
						begin
							@@fminer.AddCompound(smiles,id)
							@@fminer.AddActivity(activity, id)
              g_hash[id]=activity # DV: insert global information
						rescue
							LOGGER.warn "Could not add " + smiles + "\t" + act.to_s + " to fminer"
						end
					end
				end
				id += 1
			end
		end
    g_array=g_hash.values # DV: calculation of global median for effect calculation
    g_median=OpenTox::Utils.median(g_array)
		minfreq = (0.02*id).round
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
				else #regression part
					ids = f[2]
                    # DV: effect calculation
                    f_arr=Array.new
                    f[2].each do |id|
                        f_arr.push(g_hash[id]) 
                    end 
                    f_median=OpenTox::Utils.median(f_arr)
                    if g_median >= f_median 
						effect = 'activating'
					else
						effect = 'deactivating'
                    end
				end

				tuple = {
					url_for('/fminer#smarts',:full) => smarts,
					url_for('/fminer#p_value',:full) => p_value.to_f,
					url_for('/fminer#effect',:full) => effect
				}
				#LOGGER.debug "#{f[0]}\t#{f[1]}\t#{effect}"
				ids.each do |id|
					feature_dataset.data[compounds[id]] = [] unless feature_dataset.data[compounds[id]]
					feature_dataset.data[compounds[id]] << {bbrc_uri => tuple}
				end
			end
		end

		uri = feature_dataset.save 
		LOGGER.debug "Fminer finished, dataset #{uri} created."
    uri
	end
	LOGGER.debug "Fimer task started: "+task_uri.to_s
	response['Content-Type'] = 'text/uri-list'
	halt 202,task_uri.to_s+"\n"
end
