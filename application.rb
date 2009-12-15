require 'rubygems'
require 'libfminer/fminer' # has to be included before openbabel, otherwise we have strange SWIG overloading problems
gem 'opentox-ruby-api-wrapper', '~>1.2'
require 'opentox-ruby-api-wrapper'

#require 'smarts.rb'
#require 'similarity.rb'
require 'fminer.rb'
require 'lazar.rb'

#set :default_content, :yaml

get '/?' do
	[ url_for('/lazar', :full), url_for('/fminer', :full) ].join("\n")
end
