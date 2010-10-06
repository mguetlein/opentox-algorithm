require 'rubygems'
require File.join(File.expand_path(File.dirname(__FILE__)), 'libfminer/libbbrc/bbrc') # has to be included before openbabel, otherwise we have strange SWIG overloading problems
gem "opentox-ruby-api-wrapper", "= 1.6.2.1"
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
  uri_list = [ url_for('/lazar', :full), url_for('/fminer', :full) ].join("\n") + "\n"
  case request.env['HTTP_ACCEPT'].to_s
  when /text\/html/
    content_type "text/html"
    OpenTox.text_to_html uri_list    
  else
    content_type 'text/uri-list'
    uri_list
  end
end
