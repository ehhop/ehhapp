require "sinatra/base"
require "grit"
require "yaml"
require "require_all"

require_all "lib/"

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

