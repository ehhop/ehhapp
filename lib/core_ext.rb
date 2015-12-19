require 'yaml'

class Hash
  # When we serialize to YAML in this app, we want to keep hash
  # keys in alphabetical order wherever possible
  # (it facilitates branching and merging them later)
  def to_yaml(opts = {})
    YAML::quick_emit(self, opts) do |out|
      # Ordinarily this would be out.map(taguri, to_yaml_style) but
      # I do not want the !ruby:Object/Hash taguri in the output
      out.map(nil, to_yaml_style) do |map|
        keys.sort.each do |k|
          v = self[k]
          map.add(k, v)
        end
      end
    end
  end

  def deep_merge!(second)
    merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
    self.merge!(second, &merger)
  end
end

class String
  def undent
    gsub(/^.{#{slice(/^ +/).length}}/, '')
  end

  unless String.method_defined?(:start_with?)
    def start_with? prefix
      prefix = prefix.to_s
      self[0, prefix.length] == prefix
    end
  end
  
  def to_classname
    split(/[_-]/).map {|s| s.capitalize}.join('')
  end
end

class Time
  def to_pretty
    a = (Time.now-self).to_i

    case a
      when 0 then 'just now'
      when 1 then 'a second ago'
      when 2..59 then a.to_s+' seconds ago' 
      when 60..119 then 'a minute ago' #120 = 2 minutes
      when 120..3540 then (a/60).to_i.to_s+' minutes ago'
      when 3541..7100 then 'an hour ago' # 3600 = 1 hour
      when 7101..82800 then ((a+99)/3600).to_i.to_s+' hours ago' 
      when 82801..172000 then 'a day ago' # 86400 = 1 day
      when 172001..518400 then ((a+800)/(60*60*24)).to_i.to_s+' days ago'
      when 518400..1036800 then 'a week ago'
      else ((a+180000)/(60*60*24*7)).to_i.to_s+' weeks ago'
    end
  end
end
