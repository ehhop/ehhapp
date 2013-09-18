require "sinatra/base"
require "grit"
require "rdiscount"
require "yaml"

# A mobile-optimized wiki for the East Harlem Health Outreach
# Partnership, Icahn School of Medicine at Mount Sinai, NY, NY
#
# Original license for git-wiki.rb is WTFPL
# License for this fork is MIT (see README.markdown)

module GitWiki
  
  class << self
    attr_accessor :homepage, :extension, :repository
  end

  def self.new(repository, extension, homepage)
    self.homepage   = homepage
    self.extension  = extension
    self.repository = Grit::Repo.new(repository)

    App
  end

  class PageNotFound < Sinatra::NotFound
    attr_reader :name

    def initialize(name)
      @name = name
    end
  end

  class Page
    METADATA_FIELDS = {
      'template' => 'show',
      'title' => ''
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
      # Apply appropriate post-translational modifications based on specified template
      RDiscount.new(wiki_link(body)).to_html
    end

    def to_s
      name
    end
    
    def to_hash
      {
        "name" => name,
        "body" => body,
        "metadata" => metadata,
        "to_html" => to_html
      }
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

  class App < Sinatra::Base
    set :app_file, __FILE__
    set :views, [settings.root + '/templates', settings.root + '/_layouts']
    
    # Allow templates in multiple folders.  The ones in _layouts are special and
    # can't be set as a template for a Page.  The ones in templates *can* be set as
    # a template for a Page by the user.
    helpers do
      def find_template(views, name, engine, &block)
        Array(views).each { |v| super(v, name, engine, &block) }
      end
      
      # Allow enumeration of the templates that can be set as a template in a Page's metadata
      def templates
        Dir["#{ settings.views[0] }/*.liquid"].map{|f| File.basename(f, '.liquid') }
      end
    end

    error PageNotFound do
      page = request.env["sinatra.error"].name
      redirect "/#{page}/edit"
    end

    before do
      content_type "text/html", :charset => "utf-8"
    end

    get "/" do
      redirect "/" + GitWiki.homepage
    end

    get "/pages" do
      @pages = Page.find_all
      liquid :list, :locals => {:pages => @pages.map(&:to_hash), :page => {"name" => "pages"}}
    end

    get "/:page/edit" do
      @page = Page.find_or_create(params[:page])
      p @page.to_hash
      liquid :edit, :locals => {:page => @page.to_hash, :templates => templates}
    end

    get "/:page" do
      @page = Page.find(params[:page])
      template = @page.metadata['template']
      template = templates.include?(template) ? template.to_sym : :show
      liquid template, :locals => {:page => @page.to_hash}
    end

    post "/:page" do
      @page = Page.find_or_create(params[:page])
      new_metadata = {}
      Page::METADATA_FIELDS.each { |k, default| new_metadata[k] = params[k.to_sym] || default }
      @page.update_content(params[:body], new_metadata)
      redirect "/#{@page}"
    end

  end
end

