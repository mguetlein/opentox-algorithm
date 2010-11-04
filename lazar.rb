get '/lazar/?' do

  metadata = {
    DC.title => 'lazar',
    DC.identifier => url_for("",:full),
    DC.creator => "helma@in-silico.ch, andreas@maunz.de",
    DC.contributor => "vorgrimmlerdavid@gmx.de",
    OT.isA => OTA.ClassificationLazySingleTarget
  }

  parameters = [
    { DC.description => "Dataset URI", OT.paramScope => "mandatory", OT.title => "dataset_uri" },
    { DC.description => "Feature URI for dependent variable", OT.paramScope => "mandatory", OT.title => "prediction_feature" },
    { DC.description => "URI of feature genration service", OT.paramScope => "mandatory", OT.title => "feature_generation_uri" }
  ]

  s = OpenTox::Serializer::Owl.new
  s.add_algorithm(url_for('/lazar',:full),metadata,parameters)
	response['Content-Type'] = 'application/rdf+xml'
  s.to_rdfxml

end

post '/lazar/?' do # create a model

	dataset_uri = "#{params[:dataset_uri]}"

	begin
		training_activities = OpenTox::Dataset.new(dataset_uri)
    training_activities.load_all
	rescue => e
		halt 404, "Dataset #{dataset_uri} not found (#{e.inspect})." 
  end

  halt 404, "No prediction_feature parameter." unless params[:prediction_feature]
	halt 404, "No feature_generation_uri parameter." unless params[:feature_generation_uri]
	halt 404, "No feature #{params[:prediction_feature]} in dataset #{params[:dataset_uri]}. (features: "+
    training_activities.features.inspect+")" unless training_activities.features and training_activities.features.include?(params[:prediction_feature])

  response['Content-Type'] = 'text/uri-list' 
  task_uri = OpenTox::Task.as_task("Create lazar model",url_for('/lazar',:full)) do |task|

		# create features
		feature_dataset_uri = OpenTox::Algorithm::Fminer.new.run(params).to_s
		
		training_features = OpenTox::Dataset.new(feature_dataset_uri)
    training_features.load_all
		halt 404, "Dataset #{feature_dataset_uri} not found." if training_features.nil?
        
		lazar = OpenTox::Model::Lazar.new

    # TODO: dataset method for iterating over data entries
    training_features.data_entries.each do |compound,entry|
			lazar.fingerprints[compound] = [] unless lazar.fingerprints[compound]
      entry.keys.each do |feature|
        # TODO fix URI
        fminer_uri = File.join CONFIG[:services]["opentox-algorithm"], "fminer"
        smarts = training_features.features[feature]["#{fminer_uri}#smarts"]
        lazar.fingerprints[compound] << smarts
        unless lazar.features.include? smarts
          lazar.features << smarts
          lazar.p_values[smarts] = training_features.features[feature]["#{fminer_uri}#p_value"]
          lazar.effects[smarts] = training_features.features[feature]["#{fminer_uri}#effect"]
        end
      end
      
			lazar.activities[compound] = [] unless lazar.activities[compound]
      training_activities.data_entries[compound][params[:prediction_feature]].each do |value|
				case value.to_s
				when "true"
					lazar.activities[compound] << true
				when "false"
					lazar.activities[compound] << false
				else 
					lazar.activities[compound] << value.to_f
          lazar.type = "regression"
				end
			end
    end

    lazar.metadata[OT.dependentVariables] = params[:prediction_feature]
    lazar.metadata[OT.trainingDataset] = dataset_uri
		lazar.metadata[OT.featureDataset] = feature_dataset_uri
		
		model_uri = lazar.save
		LOGGER.info model_uri + " created #{Time.now}"
    model_uri
	end
  halt 202,task_uri
end

post '/property_lazar/?' do # create a model

	LOGGER.debug "Dataset: '" + params[:dataset_uri].to_s + "'"
	LOGGER.debug "Endpoint: '" + params[:prediction_feature].to_s + "'"
	LOGGER.debug "Feature dataset: '" + params[:feature_dataset_uri].to_s + "'"
	dataset_uri = "#{params[:dataset_uri]}"

	begin
		training_activities = OpenTox::Dataset.find(dataset_uri)
	rescue
		halt 404, "Dataset #{dataset_uri} not found" 
  end

  halt 404, "No prediction_feature parameter." unless params[:prediction_feature]
	halt 404, "No feature_dataset_uri parameter." unless params[:feature_dataset_uri]
	halt 404, "No feature #{params[:prediction_feature]} in dataset #{params[:dataset_uri]}. (features: "+
    training_activities.features.inspect+")" unless training_activities.features and training_activities.features.include?(params[:prediction_feature])

  response['Content-Type'] = 'text/uri-list' 
  task_uri = OpenTox::Task.as_task("Create lazar model",url_for('/property_lazar',:full)) do |task|

		# create features
		#LOGGER.debug "Starting fminer"
    #params[:feature_uri] = params[:prediction_feature]
		#fminer_task_uri = OpenTox::Algorithm::Fminer.create_feature_dataset(params)
		#fminer_task = OpenTox::Task.find(fminer_task_uri)
		#fminer_task.wait_for_completion
		#raise "fminer failed" unless fminer_task.completed?
    
		#LOGGER.debug "Fminer finished #{Time.now}"
		feature_dataset_uri = params[:feature_dataset_uri]
		training_features = OpenTox::Dataset.find(feature_dataset_uri)
		halt 404, "Dataset #{feature_dataset_uri} not found." if training_features.nil?
		lazar = OpenTox::Model::PropertyLazar.new
		lazar.trainingDataset = dataset_uri
		lazar.feature_dataset_uri = feature_dataset_uri
		#halt 404, "More than one descriptor type" unless training_features.features.size == 1
    lazar.features = training_features.features
		training_features.data.each do |compound,features|
			lazar.properties[compound] = {} unless lazar.properties[compound]
      LOGGER.debug features.inspect
      if features
      features.each do |f|
        f.each do |name,value|
			#lazar.features.each do |feature|
          lazar.properties[compound][name] = value
        #lazar.properties[compound] = features
        end
      end
      end
    end

		activities = {}
		classification = true
		training_activities.data.each do |compound,features|
			lazar.activities[compound] = [] unless lazar.activities[compound]
			features.each do |feature|
				case feature[params[:prediction_feature]].to_s
				when "true"
					lazar.activities[compound] << true
				when "false"
					lazar.activities[compound] << false
				else 
					lazar.activities[compound] << feature[params[:prediction_feature]].to_f
					classification = false
				end
			end
		end
		if classification
			lazar.dependentVariables = params[:prediction_feature]+"_lazar_classification"
		else
			lazar.dependentVariables = params[:prediction_feature]+"_lazar_regression"
		end
		
		model_uri = lazar.save
		LOGGER.info model_uri + " created #{Time.now}"
    model_uri
	end
  halt 202,task_uri
end
