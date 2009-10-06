class Dataset

	attr_reader :uri, :name, :members

	# key: /datasets
	# set: dataset uris
	# key: /dataset/:dataset/compounds
	# set: compound uris
	# key: /dataset/:dataset/features
	# set: feature uris
	# key: /dataset/:dataset/compound/:inchi
	# set: feature uris
	
	def initialize(uri)
		@uri = uri
		begin
			@name = URI.decode(URI.split(uri)[5].split(/\//)[1])
		rescue
			puts "Bad URI #{uri}"
		end
		@members = @@redis.set_members(uri)
	end

	def self.find(uri)
		Dataset.new(uri)
	end

	def self.base_uri
		@@config[:services]["opentox-dataset"]
	end

	def tanimoto(set_uri)
		union_size = @@redis.set_union(@uri,set_uri).size
		intersect_size = @@redis.set_intersect(@uri,set_uri).size
		"#{intersect_size.to_f/union_size.to_f}"
	end

	def weighted_tanimoto(set_uri)
		union = @@redis.set_union(@uri,set_uri)
		intersect = @@redis.set_intersect(@uri,set_uri)

		p_sum_union = 0.0
		p_sum_intersect = 0.0

		union.each{ |f| p_sum_union += OpenTox::Utils::gauss(OpenTox::Feature.new(:uri => f).value('p_value').to_f) }
		intersect.each{ |f| p_sum_intersect += OpenTox::Utils::gauss(OpenTox::Feature.new(:uri => f).value('p_value').to_f) }
		"#{p_sum_intersect/p_sum_union}"
	end

end
