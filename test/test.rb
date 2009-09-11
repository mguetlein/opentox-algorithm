require 'application'
require 'test/unit'
require 'rack/test'

set :environment, :test

class FminerTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

	def setup
		@dataset = OpenTox::Dataset.create :name => "Hamster Carcinogenicity"
	 	@dataset.import :csv => File.join(File.dirname(__FILE__), "hamster_carcinogenicity.csv"), :compound_format => "smiles"
	end

	def teardown
		@dataset.delete
	end

	def test_create_bbrc
		post '/', :dataset_uri => @dataset.uri
		assert last_response.ok?
		@feature_dataset = OpenTox::Dataset.find :uri => last_response.body
		assert last_response.body.include?('_BBRC_representatives')
		response = RestClient.get "#{File.join(@dataset.uri + '_BBRC_representatives' , 'compound/InChI=1S/C12H9NO2/c14-13(15)11-7-6-9-5-4-8-2-1-3-10(11)12(8)9/h1-3,6-7H,4-5H2/')}"
		assert !response.include?('not found')
		puts response
		@feature_dataset.delete
	end
end
