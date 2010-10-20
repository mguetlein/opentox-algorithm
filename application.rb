require 'rubygems'
require File.join(File.expand_path(File.dirname(__FILE__)), 'last-utils/lu.rb') # AM LAST
gem "opentox-ruby-api-wrapper", "= 1.6.5"
require 'opentox-ruby-api-wrapper'

#require 'smarts.rb'
#require 'similarity.rb'
require 'openbabel.rb'
require 'fminer.rb'
require 'lazar.rb'

set :lock, true

before do
	LOGGER.debug "Request: " + request.path
end

get '/?' do
	response['Content-Type'] = 'text/uri-list'
	[ url_for('/lazar', :full), url_for('/fminer', :full) ].join("\n") + "\n"
end
