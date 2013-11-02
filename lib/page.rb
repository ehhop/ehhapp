require "grit"
require "rdiscount"
require_relative "core_ext"

module GitWiki

  class Page
    METADATA_FIELDS = {
      'template' => 'unstyled',
      'title' => '',
      'author' => nil,
      'last_modified' => nil,
      'owner' => nil
    }
    
    EMPTY_AS_HASH = {
      "name" => "",
      "body" => "",
      "metadata" => {},
      "to_html" => "",
      "new" => true
    }
  
    def self.find_all
      return [] if repository.tree.contents.empty?
      repository.tree.contents.collect { |blob| new(blob).to_hash }
    end

    def self.find(name)
      page_blob = find_blob(name)
      raise PageNotFound.new(name) unless page_blob
      new(page_blob)
    end

    def self.find_or_create(name)
      find(name)
    rescue PageNotFound
      new(create_blob_for(name))
    end

    def self.css_class_for(name)
      find(name)
      "exists"
    rescue PageNotFound
      "unknown"
    end

    def self.repository
      GitWiki.repository || raise
    end

    def self.extension
      GitWiki.extension || raise
    end
    
    def self.empty(name)
      EMPTY_AS_HASH.clone.merge({"name" => name, "metadata" => METADATA_FIELDS.clone})
    end
    
    def self.get_template(name)
      GitWiki.const_get(name.to_classname)
    end

    def self.find_blob(page_name)
      repository.tree/(page_name + extension)
    end
    private_class_method :find_blob

    def self.create_blob_for(page_name)
      Grit::Blob.create(repository, {
        :name => page_name + extension,
        :data => ""
      })
    end
    private_class_method :create_blob_for

    def initialize(blob)
      @blob = blob
      extract_front_matter
    end

    def to_html
      # wiki_link content and translate to HTML
      html = RDiscount.new(wiki_link(body)).to_html
      # Apply appropriate post-translational modifications based on specified template
      begin
        if metadata["template"]
          html = self.class.get_template(metadata["template"]).new(html).transform
        end
      rescue NameError; end
      html
    end

    def to_s
      name
    end
  
    def to_hash
      EMPTY_AS_HASH.clone.merge({
        "name" => name,
        "body" => body,
        "metadata" => metadata,
        "to_html" => to_html,
        "new" => new?
      })
    end

    def new?
      @blob.id.nil?
    end

    def name
      @blob.name.gsub(/#{File.extname(@blob.name)}$/, '')
    end

    def content
      @blob.data
    end
  
    attr_reader :metadata, :body

    def update_content(new_body, new_metadata = {})
      new_content = "#{ new_metadata.to_yaml }--- \n#{ new_body }"
      return if new_content == content
      File.open(file_name, "w") { |f| f << new_content }
      add_to_index_and_commit!
    end

    private
    def extract_front_matter
      if content =~ /\A(---\s*\n.*?\n?)^(---\s*$\n?)/m
        @metadata = YAML.load($1)
        @body = $'
      else
        @metadata = METADATA_FIELDS.clone
        @body = content
      end
    end
  
    def add_to_index_and_commit!
      Dir.chdir(self.class.repository.working_dir) {
        self.class.repository.add(@blob.name)
      }
      self.class.repository.commit_index(commit_message)
    end

    def file_name
      File.join(self.class.repository.working_dir, name + self.class.extension)
    end

    def commit_message
      new? ? "Created #{name}" : "Updated #{name}"
    end

    def wiki_link(str)
      str.gsub(/\[\[ *([a-z]+[A-Za-z0-9_-]+) *\]\]/) { |m|
        %Q{<a class="#{self.class.css_class_for($1)}"} +
          %Q{href="/#{$1}">#{$1}</a>}
      }
    end
  end

end