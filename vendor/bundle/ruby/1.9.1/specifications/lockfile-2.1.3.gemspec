# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "lockfile"
  s.version = "2.1.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ara T. Howard"]
  s.date = "2014-03-04"
  s.description = "a ruby library for creating perfect and NFS safe lockfiles"
  s.email = "ara.t.howard@gmail.com"
  s.executables = ["rlock"]
  s.files = ["bin/rlock"]
  s.homepage = "https://github.com/ahoward/lockfile"
  s.licenses = ["Ruby"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "codeforpeople"
  s.rubygems_version = "1.8.23"
  s.summary = "lockfile"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
