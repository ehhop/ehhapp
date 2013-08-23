#!/usr/bin/env rackup
require File.dirname(__FILE__) + "/git-wiki"

run GitWiki.new(File.dirname(__FILE__) + "/ehhapp-data", ".markdown", "index")
