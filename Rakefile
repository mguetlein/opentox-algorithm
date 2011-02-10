require 'rubygems'
require 'rake'
require 'opentox-ruby'

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
      puts `echo "Fminer/LibBbrc successfully configured."`
    else
      puts `echo "Fminer/LibBbrc configuration failed!"`
      exit
    end
    puts `make ruby`
    Dir.chdir('../liblast')
    puts `git checkout master`
    puts `git pull`
    puts `./configure`
    if $? == 0
      puts `echo "Fminer/LibLast successfully configured."`
    else
      puts `echo "Fminer/LibLast configuration failed!"`
      exit
    end
    puts `make ruby`
    Dir.chdir('../../last-utils')
    #puts `git fetch`
    # AM LAST: need branch 'experimental' until merged to master in last-utils
    #puts `git checkout -f -b experimental origin/experimental` 
    puts `git checkout master`
    puts `git pull`
  end

  desc "Update gems and fminer"
  task :update do
    puts `git submodule update --init`
    Dir.chdir('libfminer/libbbrc')
    puts `git checkout Makefile`
    puts `git pull`
    puts `./configure`
    if $? == 0
      puts `echo "Fminer/LibBbrc successfully configured."`
    else
      puts `echo "Fminer/LibBbrc configuration failed!"`
      exit
    end
    puts `make ruby`
    Dir.chdir('../liblast')
    puts `git checkout Makefile`
    puts `git pull`
    puts `./configure`
    if $? == 0
      puts `echo "Fminer/LibLast successfully configured."`
    else
      puts `echo "Fminer/LibLast configuration failed!"`
      exit
    end
    puts `make ruby`
    Dir.chdir('../../last-utils')
    #puts `git fetch`
    # AM LAST: need branch 'experimental' until merged to master in last-utils
    #puts `git checkout -f -b experimental origin/experimental`
    puts `git checkout master`
    puts `git pull`
  end
end
desc "Run tests"
task :test do
  load 'test/test.rb'
end

