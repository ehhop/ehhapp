#!/usr/bin/env rackup
require File.dirname(__FILE__) + "/git-wiki"

run GitWiki.new(File.expand_path(ARGV[1] || "../ehhapp-data"),
  ARGV[2] || ".markdown", ARGV[3] || "Home")
