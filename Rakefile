require 'rubygems'
require 'rake'

desc "Install required gems and openbabel"
task :install do
	`sudo gem sources -a http://gems.github.com`
	`sudo gem install sinatra helma-opentox-ruby-api-wrapper`
	`git submodule init`
	`git submodule update`
	Dir.cd('libfminer')
	`git pull`
	`make ruby`
end

desc "Run tests"
task :test do
	puts "No tests for fminer."
	#load 'test.rb'
end

