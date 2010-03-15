get '/lazar/?' do
	response['Content-Type'] = 'application/rdf+xml'
	OpenTox::Algorithm::Lazar.new.rdf
end

post '/lazar/?' do # create a model

	LOGGER.debug "Dataset: " + params[:dataset_uri]
	LOGGER.debug "Endpoint: " + params[:feature_uri]
	LOGGER.debug "Feature generation: " + params[:feature_generation_uri]
	dataset_uri = "#{params[:dataset_uri]}"
	begin
		training_activities = OpenTox::Dataset.find(dataset_uri)
	rescue
		LOGGER.error "Dataset #{dataset_uri} not found" 
		halt 404, "Dataset #{dataset_uri} not found" 
	end
	halt 404, "No feature_uri parameter." unless params[:feature_uri]
	halt 404, "No feature_generation_uri parameter." unless params[:feature_generation_uri]

	task = OpenTox::Task.create

	pid = Spork.spork(:logger => LOGGER) do

		task.started
		LOGGER.debug "Lazar task #{task.uri} started #{Time.now}"

		# create features
		LOGGER.debug "Starting fminer"
		fminer_task_uri = OpenTox::Algorithm::Fminer.create_feature_dataset(params)
		fminer_task = OpenTox::Task.find(fminer_task_uri)
		fminer_task.parent = task
		fminer_task.wait_for_completion
		if fminer_task.failed?
			LOGGER.error "Fminer failed"
			task.failed
			break
		end
		LOGGER.debug "Fminer finished #{Time.now}"
		feature_dataset_uri = fminer_task.resource
		training_features = OpenTox::Dataset.find(feature_dataset_uri)
		halt 404, "Dataset #{feature_dataset_uri} not found." if training_features.nil?
		lazar = OpenTox::Model::Lazar.new
		lazar.dependent_variable = params[:feature_uri]
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
		training_activities.data.each do |compound,features|
			lazar.activities[compound] = [] unless lazar.activities[compound]
			features.each do |feature|
				case feature[params[:feature_uri]].to_s
				when "true"
					lazar.activities[compound] << true
				when "false"
					lazar.activities[compound] << false
				else 
					lazar.activities[compound] << f.to_s
				end
			end
		end
		

		model_uri = lazar.save
		LOGGER.info model_uri + " created #{Time.now}"

		task.completed(model_uri)
	end
	LOGGER.debug "Lazar task PID: " + pid.to_s
	task.pid = pid
	#status 303
	response['Content-Type'] = 'text/uri-list'
	task.uri + "\n"

end
