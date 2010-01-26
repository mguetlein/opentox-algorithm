require 'rubygems'
require 'rake'
require 'tasks/opentox'

namespace "fminer" do
	desc "Install required gems and fminer"
	task :install do
		puts `git submodule init`
		puts `git submodule update`
		Dir.chdir('libfminer')
		puts `git checkout master`
		puts `git pull`
		puts `./configure`
        puts `make ruby`
	end

	desc "Update gems and fminer"
	task :update do
		puts `git submodule update`
		Dir.chdir('libfminer')
		puts `git checkout master`
		puts `git pull`
		puts `./configure`
		puts `make ruby`
	end
end

desc "Run tests"
task :test do
	load 'test/test.rb'
end

