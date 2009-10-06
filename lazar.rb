post '/lazar_classification/?' do # create a model
	OpenTox::Model::LazarClassification.create(params).uri
end
