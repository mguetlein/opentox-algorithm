LOGGER.progname = File.expand_path(__FILE__)

get '/lazar/?' do
	response['Content-Type'] = 'application/rdf+xml'
	OpenTox::Algorithm::Lazar.new.rdf
end

post '/lazar/?' do # create a model

	LOGGER.debug "Dataset: " + params[:dataset_uri]
	LOGGER.debug "Endpoint: " + params[:feature_uri]
	LOGGER.debug "Feature generation: " + params[:feature_generation_uri]
	dataset_uri = "#{params[:dataset_uri]}?feature_uris\\[\\]=#{CGI.escape(params[:feature_uri])}"
	begin
		training_activities = OpenTox::Dataset.find(dataset_uri)
	rescue
		LOGGER.error "Dataset #{dataset_uri} not found" 
		halt 404, "Dataset #{dataset_uri} not found" 
	end
	halt 404, "No feature_uri parameter." unless params[:feature_uri]
	halt 404, "No feature_generation_uri parameter." unless params[:feature_generation_uri]

	task = OpenTox::Task.create
#	model = OpenTox::Model::Lazar.create(task)
#	LOGGER.debug model.inspect

	pid = Spork.spork(:logger => LOGGER) do

		task.started
		LOGGER.debug "Lazar task #{task.uri} started #{Time.now}"

		# create features
		LOGGER.debug "Starting fminer"
		fminer_task_uri = OpenTox::Algorithm::Fminer.create_feature_dataset(params)
		LOGGER.debug "Fminer started"
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
		features = []
		p_vals = {}
		effects = {}
		fingerprints = {}
		training_features.data.each do |compound,feature|
			fingerprints[compound] = [] unless fingerprints[compound]
			feature.each do |uri,fragments|
				if uri.match(/BBRC_representative/)
					fragments.each do |f|
						fingerprints[compound] << f['smarts']
						unless features.include? f['smarts']
							features << f['smarts']
							p_vals[f['smarts']] = f['p_value'].to_f
							effects[f['smarts']] = f['effect']
						end
					end
				end
			end
		end
		activities = {}
		training_activities.data.each do |compound,feature|
			activities[compound] = [] unless activities[compound]
			feature[params[:feature_uri]].each do |f|
				case f.to_s
				when "true"
					activities[compound] << true
				when "false"
					activities[compound] << false
				else 
					activities[compound] << f.to_s
				end
			end
		end
		
		yaml = {
			:activity_dataset => params[:dataset_uri],
			:feature_dataset => feature_dataset_uri.to_s,
			:endpoint => params[:feature_uri],
			:features => features,
			:p_values => p_vals,
			:effects => effects,
			:fingerprints => fingerprints,
			:activities => activities
		}.to_yaml
		LOGGER.debug yaml

		model_uri = OpenTox::Model::Lazar.create(yaml)
		LOGGER.info model_uri + " created #{Time.now}"

		task.completed(model_uri)
	end
	LOGGER.debug "Lazar task PID: " + pid.to_s
	task.pid = pid
	#status 303
	response['Content-Type'] = 'text/uri-list'
	task.uri
	#model.uri

end
