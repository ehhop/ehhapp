require "grit"
require "yaml"
require "pstore"
require "./lib/core_ext.rb"
require "pp"

puts "Setting up wiki pstore..."
t1 = Time.now
config = YAML::load(File.open("config.dist.yaml"))
config.merge!(YAML::load(File.open("config.yaml")))
repository = Grit::Repo.new(config["repo"])
File.delete(File.expand_path("ehhapp_wiki.pstore", Dir.tmpdir)) if File.exists?(File.expand_path("ehhapp_wiki.pstore", Dir.tmpdir))
store  = PStore.new(File.expand_path("ehhapp_wiki.pstore", Dir.tmpdir))
store.ultra_safe = true
withdraw_amt = 25
skip=0
result = []
begin
  result = repository.commits('master', withdraw_amt, skip)
  result.each do |com|
    com.diffs.each do |diff| 
      store.transaction do
        !(diff.a_path =~ /(.*).md/)
        store[$1] ||= []
        store[$1].unshift(com.id)
      end
    end
  end
  skip = skip + withdraw_amt
end while result.length == withdraw_amt
t2= Time.now
puts "wiki pstore setup complete!\nIt took roughly #{t2-t1} seconds to process around #{skip} commits."
