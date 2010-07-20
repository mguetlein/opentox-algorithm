require File.join(File.dirname(__FILE__),'dataset.rb')

helpers do
def find
# + charges are dropped
uri = uri(params[:splat].first.gsub(/(InChI.*) (.*)/,'\1+\2')) # reinsert dropped '+' signs in InChIs
halt 404, "Dataset \"#{uri}\" not found." unless @set = Dataset.find(uri)
end

def uri(name)
name = URI.encode(name)
uri = File.join Dataset.base_uri, name
end
end

get '/tanimoto/dataset/*/dataset/*/?' do
find
@set.tanimoto(uri(params[:splat][1]))
end

get '/weighted_tanimoto/dataset/*/dataset/*/?' do
find
@set.weighted_tanimoto(uri(params[:splat][1]))
end


