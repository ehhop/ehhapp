require "sinatra/base"
require "grit"
require "yaml"
require "require_all"
require "rdiscount"
require "pp"

require_all "lib/"

# A mobile-optimized wiki for the East Harlem Health Outreach
# Partnership, Icahn School of Medicine at Mount Sinai, NY, NY
#
# Original license for git-wiki.rb is WTFPL
# License for this fork is MIT (see README.markdown)

module GitWiki
  
  class << self
    attr_accessor :homepage, :extension, :config, :repository, :template_cache, :mdown_examples
  end
  
  self.config = YAML::load(File.open("config.dist.yaml"))
  self.template_cache = nil

  def self.new(config, extension, homepage)
    self.homepage   = homepage
    self.extension  = extension
    self.config.merge!(YAML::load(File.open(config)))
    self.repository = Grit::Repo.new(self.config["repo"])
    self.mdown_examples = self.config["mdown_examples"].map do |ex|
      {
        "mdown" => ex,
        "html" => RDiscount.new(ex).to_html
      }
    end

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
    
    register Sinatra::EmailAuth
    set :config, GitWiki.config
    
    # Allow templates in multiple folders.  The ones in _layouts are special and
    # can't be set as a template for a Page.  The ones in templates *can* be set as
    # a template for a Page by the user.
    helpers do
      def find_template(views, name, engine, &block)
        Array(views).each { |v| super(v, name, engine, &block) }
      end
      
      # Allow enumeration of the templates that can be set as a template in a Page's metadata
      def templates
        GitWiki.template_cache ||= Dir["#{ settings.views[0] }/*.liquid"].map do |f|
          name = File.basename(f, '.liquid')
          {
            "name" => name,
            "examples" => Page.get_template(name).examples
          }
        end
      end
      
      def header(page)
        liquid :header, :layout => false, :locals => locals(page)
      end
            
      def locals(page, and_these = {})
        {
          :just_auth => @just_auth, 
          :username => @username,
          :page => page.to_hash,
          :nocache => false,
          :is_editor => @is_editor,
          :templates => templates,
          :editors => editors
        }.merge(and_these)
      end
    end

    # error PageNotFound do
    #   page = request.env["sinatra.error"].name
    #   redirect "/#{page}/edit" unless ["favicon.ico"].include? page
    # end

    before do
      content_type "text/html", :charset => "utf-8"
      @just_auth = !!session[:just_auth]
      session[:just_auth] = false
      @username = username
      @is_editor = is_editor?
    end

    get "/" do
      redirect "/" + GitWiki.homepage
    end

    # NOTE: this route is a holdover from git-wiki and really isn't being used for anything, yet.
    get "/pages" do
      @pages = Page.find_all
      liquid :list, :locals => {:pages => @pages.map(&:to_hash), :page => {"name" => "pages"}}
    end

    # TODO: for all of these routes, we should validate if params[:page] is actually
    #   a plausible page name, and forbid ones with special characters
    # TODO: We should add the ability to specify and edit a "back" destination within page metadata

    get "/:page/edit" do
      authorize! "/#{params[:page]}"
      @page = Page.find_or_create(params[:page])
      liquid :edit, :locals => locals(@page, :page_class => 'editor', :nocache => true, 
          :mdown_examples => GitWiki.mdown_examples)
    end

    get "/:page" do
      begin
        @page = Page.find(params[:page])
        template = @page.metadata["template"]
        template = templates.detect{|t| t["name"] == template } ? template.to_sym : :show
        # TODO: make header able to swap login/logout button to back button set in page metadata
        liquid template, :locals => locals(@page, :header => header(@page))
      rescue PageNotFound => err
        empty_page = Page.empty(err.name)
        liquid :empty, :locals => locals(empty_page, :header => header(empty_page))
      end
    end

    post "/:page" do
      authorize! "/#{params[:page]}"
      
      # TODO: perhaps this should find the latest page according to the HEAD of the 
      #   git branch of the current user
      @page = Page.find_or_create(params[:page])
      new_metadata = @page.metadata.clone
      
      if @is_editor
        Page::METADATA_FIELDS.each { |k, default| new_metadata[k] = params[k.to_sym] || default }
        new_metadata["author"] = username
        @page.update_content(params[:body], new_metadata)
      else
        # TODO: 
        #   If the user is not an editor, they should commit to a topic branch, and then the 
        #   owner of the page
        #   will receive an email telling them to review the changes and approve them or not.
        #   This page provides a clue on how to use grit to commit to a new branch:
        #   http://stackoverflow.com/questions/5839106/a-few-questions-about-grit
        new_metadata["author"] = username
        @page.branch_content(username, params[:body], new_metadata)
      end
      
      redirect "/#{@page}"
    end

  end
end

