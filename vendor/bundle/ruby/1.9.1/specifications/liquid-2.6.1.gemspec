# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "liquid"
  s.version = "2.6.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.7") if s.respond_to? :required_rubygems_version=
  s.authors = ["Tobias Luetke"]
  s.date = "2014-01-10"
  s.email = ["tobi@leetsoft.com"]
  s.extra_rdoc_files = ["History.md", "README.md"]
  s.files = ["History.md", "README.md"]
  s.homepage = "http://www.liquidmarkup.org"
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.23"
  s.summary = "A secure, non-evaling end user template engine with aesthetic markup."

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
