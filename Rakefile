require 'rubygems'
require 'rake'
require 'opentox-ruby-api-wrapper'
#require 'tasks/opentox'

namespace "fminer" do
	desc "Install required gems and fminer"
	task :install do
		puts `git submodule init`
		puts `git submodule update`
		Dir.chdir('libfminer/libbbrc')
		puts `git checkout master`
		puts `git pull`
		puts `./configure`
        if $? == 0
            puts `echo "Fminer successfully configured."`
        else
            puts `echo "Fminer configuration failed!"`
            exit
        end
        puts `make ruby`
	    end

	desc "Update gems and fminer"
	task :update do
		puts `git submodule update`
		Dir.chdir('libfminer/libbbrc')
		puts `git checkout master`
		puts `git pull`
		puts `./configure`
        if $? == 0
            puts `echo "Fminer successfully configured."`
        else
            puts `echo "Fminer configuration failed!"`
            exit
        end
        puts `make ruby`
        end
end
desc "Run tests"
task :test do
	load 'test/test.rb'
end

