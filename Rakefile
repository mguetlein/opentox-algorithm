require 'rubygems'
require 'rake'
require 'tasks/opentox'

desc "Install required gems and fminer"
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

desc "Update gems and fminer"
task :update do
	puts `sudo gem update sinatra helma-opentox-ruby-api-wrapper`
	puts `git submodule update`
	Dir.chdir('libfminer')
	puts `git checkout master`
	puts `git pull`
	puts `make ruby`
end

desc "Run tests"
task :test do
	load 'test/test.rb'
end

