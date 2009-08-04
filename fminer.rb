['rubygems', 'sinatra', 'rest_client', 'crack/xml', 'libfminer/fminer'].each do |lib|
	require lib
end

ENV['FMINER_SMARTS'] = 'true'

COMPOUNDS_URI = 'http://webservices.in-silico.ch/compounds/'
FEATURES_URI  = 'http://webservices.in-silico.ch/features/'
DATASETS_URI   = 'http://localhost:4567/'

post '/' do

	fminer = Fminer::Fminer.new()

	xml = Crack::XML.parse(RestClient.get params[:dataset_uri] + '/compounds')
	compounds = xml['dataset']['compounds']['compound']
	endpoint_name = xml['dataset']['name']
	id = 1
	compound_uris = []
	compounds.each do |c|
		smiles = URI.decode(c['uri'].split(/\//).last)
		c['features']['feature'].each do |feature|
			activity = feature.split(/\//).last
			case activity.to_s
			when '1'
				compound_uris[id] = c['uri']
				fminer.AddCompound(smiles,id)
				fminer.AddActivity(true, id)
				puts "#{id}\t#{smiles}\t#{activity}"
			when '0'
				compound_uris[id] = c['uri']
				fminer.AddCompound(smiles,id)
				fminer.AddActivity(false, id)
				puts "#{id}\t#{smiles}\t#{activity}"
			end
		end
		id += 1
	end

	fminer.SetConsoleOut(false)
	features = []
	# run fminer
	(0 .. fminer.GetNoRootNodes()-1).each do |j|
		result = fminer.MineRoot(j)
	 (0 .. result.size-1).each do |i|
		 features << YAML.load(result[i])[0]
		end
	end

	smarts_dataset = RestClient.post DATASETS_URI, :name => endpoint_name + ' fragments'
	significance_dataset = RestClient.post  DATASETS_URI, :name => endpoint_name + ' fragment significances'

	features.each do |f|
		smarts = f[0]
		chisq = f[1]
		ids = f[2] + f[3]
		ids.each do |id|
			compound_uri = compound_uris[id]
			smarts_uri = RestClient.post FEATURES_URI, :name => smarts, :value => chisq
			RestClient.put smarts_dataset, :compound_uri => compound_uri, :feature_uri => smarts_uri
		end
	end

	smarts_dataset + "\n" 

end
