ENV['FMINER_SMARTS'] = 'true'
ENV['FMINER_NO_AROMATIC'] = 'true'
ENV['FMINER_PVALUES'] = 'true'
@@fminer = Bbrc::Bbrc.new 
@@fminer.SetMinfreq(5)

get '/fminer/?' do

  metadata = {
    DC.title => 'fminer',
    DC.identifier => url_for("",:full),
    DC.creator => "andreas@maunz.de, helma@in-silico.ch",
    DC.contributor => "vorgrimmlerdavid@gmx.de",
    OT.isA => OTA.PatternMiningSupervised
  }

  parameters = [
    { DC.description => "Dataset URI", OT.paramScope => "mandatory", OT.title => "dataset_uri" },
    { DC.description => "Feature URI for dependent variable", OT.paramScope => "mandatory", OT.title => "prediction_feature" }
  ]

  s = OpenTox::Serializer::Owl.new
  s.add_algorithm(url_for('/fminer',:full),metadata,parameters)
	response['Content-Type'] = 'application/rdf+xml'
  s.to_rdfxml

end

post '/fminer/?' do
    
	halt 404, "Please submit a dataset_uri." unless params[:dataset_uri] and  !params[:dataset_uri].nil?
	halt 404, "Please submit a prediction_feature." unless params[:prediction_feature] and  !params[:prediction_feature].nil?
	prediction_feature = params[:prediction_feature]

  training_dataset = OpenTox::Dataset.new "#{params[:dataset_uri]}"
  training_dataset.load_all
	halt 404, "No feature #{params[:prediction_feature]} in dataset #{params[:dataset_uri]}" unless training_dataset.features and training_dataset.features.include?(params[:prediction_feature])

  task_uri = OpenTox::Task.as_task("Mining BBRC features", url_for('/fminer',:full)) do 

		feature_dataset = OpenTox::Dataset.new
    feature_dataset.add_metadata({
      DC.title => "BBRC representatives for " + training_dataset.metadata[DC.title],
      DC.creator => url_for('/fminer',:full),
      OT.hasSource => url_for('/fminer', :full),
    })
    feature_dataset.add_parameters({
      "dataset_uri" => params[:dataset_uri],
      "prediction_feature" => params[:prediction_feature]
    })
    feature_dataset.save

		id = 1 # fminer start id is not 0
		compounds = []
    nr_active=0
    nr_inactive=0
    g_hash = Hash.new# DV: for effect calculation in regression part

		@@fminer.Reset
    training_dataset.data_entries.each do |compound,entry|
			begin
				smiles = OpenTox::Compound.new(compound.to_s).smiles
			rescue
				LOGGER.warn "No resource for #{compound.to_s}"
				next
			end
			if smiles == '' or smiles.nil?
				LOGGER.warn "Cannot find smiles for #{compound.to_s}."
        next
      end
      entry.each do |feature,values|
        values.each do |value|
					if value.nil? 
						LOGGER.warn "No #{feature} activiity for #{compound.to_s}."
					else
						case value.to_s
						when "true"
              nr_active += 1
							activity = 1
						when "false"
              nr_inactive += 1
							activity = 0
						else
							activity = value.to_f
							@@fminer.SetRegression(true)
						end
						begin
							@@fminer.AddCompound(smiles,id)
							@@fminer.AddActivity(activity, id)
              g_hash[id]=activity # DV: insert global information
              compounds[id] = compound
              id += 1
						rescue
							LOGGER.warn "Could not add " + smiles + "\t" + value.to_s + " to fminer"
						end
          end
        end
      end
    end

    g_array=g_hash.values # DV: calculation of global median for effect calculation
    g_median=OpenTox::Algorithm.median(g_array)
		
    # TODO read from params
    raise "No compounds in dataset #{training_dataset.uri}" if compounds.size==0

    features = Set.new
		# run @@fminer
		(0 .. @@fminer.GetNoRootNodes()-1).each do |j|

			results = @@fminer.MineRoot(j)
			results.each do |result|
				f = YAML.load(result)[0]
				smarts = f[0]
				p_value = f[1]

				if (!@@fminer.GetRegression) 
					ids = f[2] + f[3]
					if f[2].size.to_f/ids.size > nr_active.to_f/(nr_active+nr_inactive)
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
          f_median=OpenTox::Algorithm.median(f_arr)
          if g_median >= f_median 
            effect = 'activating'
          else
            effect = 'deactivating'
          end
        end

        feature_uri = File.join feature_dataset.uri,"feature","bbrc", features.size.to_s
        unless features.include? smarts
          features << smarts
          # TODO insert correct ontology entries
          metadata = {
            OT.hasSource => feature_dataset.uri,
            OT.smarts => smarts,
            OT.p_value => p_value.to_f,
            OT.effect => effect } 
          feature_dataset.add_feature feature_uri, metadata
        end
				ids.each { |id| feature_dataset.add(compounds[id], feature_uri, true)}
			end
		end
		feature_dataset.save 
    feature_dataset.uri
	end
	response['Content-Type'] = 'text/uri-list'
	halt 202,task_uri.to_s+"\n"
end
