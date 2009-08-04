#!/bin/bash

git submodule init
git submodule update
cd libfminer
make ruby
