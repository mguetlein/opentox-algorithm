get '/lazar/?' do
  owl = OpenTox::Owl.create 'Algorithm', url_for('/lazar',:full)
  owl.set 'title',"lazar"
  owl.set 'creator',"http://github.com/helma/opentox-algorithm"
  owl.parameters = {
    "Dataset URI" =>
      { :scope => "mandatory", :value => "dataset_uri" },
    "Feature URI for dependent variable" =>
      { :scope => "mandatory", :value => "prediction_feature" },
    "Feature generation URI" =>
      { :scope => "mandatory", :value => "feature_generation_uri" }
  }
  rdf = owl.rdf
  File.open('public/lazar.owl', 'w') {|f| f.print rdf}
	response['Content-Type'] = 'application/rdf+xml'
	rdf
end

post '/lazar/?' do # create a model

	LOGGER.debug "Dataset: '" + params[:dataset_uri].to_s + "'"
	LOGGER.debug "Endpoint: '" + params[:prediction_feature].to_s + "'"
	LOGGER.debug "Feature generation: '" + params[:feature_generation_uri].to_s + "'"
	dataset_uri = "#{params[:dataset_uri]}"

	begin
		training_activities = OpenTox::Dataset.find(dataset_uri)
	rescue
		halt 404, "Dataset #{dataset_uri} not found" 
  end

  halt 404, "No prediction_feature parameter." unless params[:prediction_feature]
	halt 404, "No feature_generation_uri parameter." unless params[:feature_generation_uri]
	halt 404, "No feature #{params[:prediction_feature]} in dataset #{params[:dataset_uri]}. (features: "+
    training_activities.features.inspect+")" unless training_activities.features and training_activities.features.include?(params[:prediction_feature])

  response['Content-Type'] = 'text/uri-list' 
  task_uri = OpenTox::Task.as_task("Create lazar model",url_for('/lazar',:full)) do |task|

		# create features
		LOGGER.debug "Starting fminer"
    params[:feature_uri] = params[:prediction_feature]
		fminer_task_uri = OpenTox::Algorithm::Fminer.create_feature_dataset(params)
		fminer_task = OpenTox::Task.find(fminer_task_uri)
		fminer_task.wait_for_completion
		raise "fminer failed" unless fminer_task.completed?
    
		LOGGER.debug "Fminer finished #{Time.now}"
		feature_dataset_uri = fminer_task.resultURI.to_s
		training_features = OpenTox::Dataset.find(feature_dataset_uri)
		halt 404, "Dataset #{feature_dataset_uri} not found." if training_features.nil?
		lazar = OpenTox::Model::Lazar.new
		lazar.trainingDataset = dataset_uri
		lazar.feature_dataset_uri = feature_dataset_uri
		halt 404, "More than one descriptor type" unless training_features.features.size == 1
		bbrc = training_features.features.first
		training_features.data.each do |compound,features|
			lazar.fingerprints[compound] = [] unless lazar.fingerprints[compound]
			features.each do |feature|
				tuple = feature[bbrc]
				if tuple
					smarts =nil; p_value = nil; effect = nil
					tuple.each do |k,v|
						case k
						when /fminer#smarts/
							smarts = v
							lazar.features << smarts
							lazar.fingerprints[compound] << smarts
						when /fminer#p_value/
							p_value = v
						when /fminer#effect/
							effect = v
						end
					end
					lazar.p_values[smarts] = p_value
					lazar.effects[smarts] = effect
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
				# AM: handle quantitative activity values of features
				else 
					lazar.activities[compound] << feature[params[:prediction_feature]].to_f
					classification = false
				end
			end
		end
		# TODO: insert regression
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
