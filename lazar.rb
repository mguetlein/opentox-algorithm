@@feature_generation_default = File.join(CONFIG[:services]["opentox-algorithm"],"fminer","bbrc")

# Get RDF/XML representation of the lazar algorithm
# @return [application/rdf+xml] OWL-DL representation of the lazar algorithm
get '/lazar/?' do
	response['Content-Type'] = 'application/rdf+xml'
  algorithm = OpenTox::Algorithm::Generic.new(url_for('/lazar',:full))
  algorithm.metadata = {
    DC.title => 'lazar',
    DC.creator => "helma@in-silico.ch, andreas@maunz.de",
    DC.contributor => "vorgrimmlerdavid@gmx.de",
    OT.isA => OTA.ClassificationLazySingleTarget,
    OT.parameters => [
      { DC.description => "Dataset URI with the dependent variable", OT.paramScope => "mandatory", DC.title => "dataset_uri" },
      { DC.description => "Feature URI for dependent variable. Optional for datasets with only a single feature.", OT.paramScope => "optional", DC.title => "prediction_feature" },
      { DC.description => "URI of feature genration service. Default: #{@@feature_generation_default}", OT.paramScope => "optional", DC.title => "feature_generation_uri" },
      { DC.description => "URI of feature dataset. If this parameter is set no feature generation algorithm will be called", OT.paramScope => "optional", DC.title => "feature_dataset_uri" },
      { DC.description => "Further parameters for the feaature generation service", OT.paramScope => "optional" }
    ]
  }
  algorithm.to_rdfxml
end

# Create a lazar prediction model
# @param [String] dataset_uri Training dataset URI
# @param [optional,String] prediction_feature URI of the feature to be predicted
# @param [optional,String] feature_generation_uri URI of the feature generation algorithm 
# @param [optional,String] - further parameters for the feature generation service 
# @return [text/uri-list] Task URI 
post '/lazar/?' do 

  halt 404, "No dataset_uri parameter." unless params[:dataset_uri]
	dataset_uri = params[:dataset_uri]

  halt 404, "Dataset #{dataset_uri} not found." unless training_activities = OpenTox::Dataset.new(dataset_uri)
  training_activities.load_all(@subjectid)

  prediction_feature = params[:prediction_feature]
  unless prediction_feature # try to read prediction_feature from dataset
    halt 404, "#{training_activities.features.size} features in dataset #{dataset_uri}. Please provide a  prediction_feature parameter." unless training_activities.features.size == 1
    prediction_feature = training_activities.features.keys.first
    params[:prediction_feature] = prediction_feature
  end

  feature_generation_uri = @@feature_generation_default unless feature_generation_uri = params[:feature_generation_uri]

	halt 404, "No feature #{prediction_feature} in dataset #{params[:dataset_uri]}. (features: "+
    training_activities.features.inspect+")" unless training_activities.features and training_activities.features.include?(prediction_feature)

  task = OpenTox::Task.create("Create lazar model",url_for('/lazar',:full)) do |task|

		lazar = OpenTox::Model::Lazar.new
    lazar.min_sim = params[:min_sim] if params[:min_sim] 

		if params[:feature_dataset_uri]
      feature_dataset_uri = params[:feature_dataset_uri]
      training_features = OpenTox::Dataset.new(feature_dataset_uri)
      case training_features.feature_type
      when "classification"
        lazar.similarity_algorithm = "Similarity.tanimoto"
      when "regression"
        lazar.similarity_algorithm = "Similarity.euclid"
      end
    else # create features
      params[:feature_generation_uri] = feature_generation_uri
      if feature_generation_uri.match(/fminer/)
        lazar.feature_calculation_algorithm = "Substructure.match"
      else
        halt 404, "External feature generation services not yet supported"
      end
      params[:subjectid] = @subjectid
      feature_dataset_uri = OpenTox::Algorithm::Generic.new(feature_generation_uri).run(params).to_s
      training_features = OpenTox::Dataset.new(feature_dataset_uri)
    end

    training_features.load_all(@subjectid)
		halt 404, "Dataset #{feature_dataset_uri} not found." if training_features.nil?

    # sorted features for index lookups
    lazar.features = training_features.features.sort if training_features.feature_type == "regression"

    training_features.data_entries.each do |compound,entry|
      lazar.fingerprints[compound] = [] unless lazar.fingerprints[compound]
      entry.keys.each do |feature|
        if feature_generation_uri.match(/fminer/)
          smarts = training_features.features[feature][OT.smarts]
          lazar.fingerprints[compound] << smarts
          unless lazar.features.include? smarts
            lazar.features << smarts
            lazar.p_values[smarts] = training_features.features[feature][OT.pValue]
            lazar.effects[smarts] = training_features.features[feature][OT.effect]
          end
        else
          case training_features.feature_type
          when "classification"
            # fingerprints are sets
            if entry[feature].flatten.size == 1
              lazar.fingerprints[compound] << feature if entry[feature].flatten.first.to_s.match(TRUE_REGEXP)
              lazar.features << feature unless lazar.features.include? feature
            else
              LOGGER.warn "More than one entry (#{entry[feature].inspect}) for compound #{compound}, feature #{feature}"
            end
          when "regression"
            # fingerprints are arrays
            if entry[feature].flatten.size == 1
              lazar.fingerprints[compound][lazar.features.index(feature)] = entry[feature].flatten.first
            else
              LOGGER.warn "More than one entry (#{entry[feature].inspect}) for compound #{compound}, feature #{feature}"
            end
          end
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
          halt 404, "0 values not allowed in training dataset. log10 is calculated internally." if value.to_f == 0
					lazar.activities[compound] << value.to_f
          lazar.prediction_algorithm = "Neighbors.local_svm_regression"
				end
			end
    end

    lazar.metadata[DC.title] = "lazar model for #{URI.decode(File.basename(prediction_feature))}"
    # TODO: fix dependentVariable
    lazar.metadata[OT.dependentVariables] = params[:prediction_feature]
    lazar.metadata[OT.trainingDataset] = dataset_uri
		lazar.metadata[OT.featureDataset] = feature_dataset_uri
    lazar.metadata[OT.isA] = OTA.ClassificationLazySingleTarget

    lazar.metadata[OT.parameters] = [
      {DC.title => "dataset_uri", OT.paramValue => dataset_uri},
      {DC.title => "prediction_feature", OT.paramValue => prediction_feature},
      {DC.title => "feature_generation_uri", OT.paramValue => feature_generation_uri}
    ]
		
		model_uri = lazar.save(@subjectid)
		LOGGER.info model_uri + " created #{Time.now}"
    model_uri
	end
  response['Content-Type'] = 'text/uri-list' 
  halt 503,task.uri+"\n" if task.status == "Cancelled"
  halt 202,task.uri
end

