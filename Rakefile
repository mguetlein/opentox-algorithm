require 'rubygems'
require 'rake'

desc "Install required gems and openbabel"
task :install do
	puts `sudo gem sources -a http://gems.github.com`
	puts `sudo gem install sinatra helma-opentox-ruby-api-wrapper`
	puts `git submodule init`
	puts `git submodule update`
	Dir.chdir('libfminer')
	puts `git checkout master`
	puts `git pull`
	puts `make ruby`
end

desc "Run tests"
task :test do
	puts "No tests for fminer."
	#load 'test.rb'
end

