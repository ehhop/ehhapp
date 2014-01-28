require "sinatra/base"
require "sinatra/json"
require "rack/csrf"
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
    
    def to_hash
      {"name" => @name, "type" => self.class.to_s}
    end
  end
  
  class BranchNotFound < PageNotFound
  end
  
  class InvalidPageName < PageNotFound
  end
 
  class App < Sinatra::Base
    set :app_file, __FILE__
    set :views, [settings.root + '/templates', settings.root + '/_layouts']
    
    use Rack::Session::Cookie
    use Rack::Csrf, :raise => true, :skip => ['POST:/.*/history', 'POST:/login']
    register Sinatra::EmailAuth
    set :config, GitWiki.config
    
    # Allow templates in multiple folders.  The ones in _layouts are special and
    # can't be set as a template for a Page.  The ones in templates *can* be set as
    # a template for a Page by the user.
    helpers Sinatra::JSON
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
      
      def uploads
        Dir["./public/uploads/*"].map{|f| File.basename f}
      end
      
      def header(page, and_these = {})
        liquid :header, :layout => false, :locals => locals(page, and_these)
      end
            
      def locals(page, and_these = {})
        {
          :just_auth => @just_auth, 
          :username => @username,
          :page => page.to_hash,
          :nocache => false,
          :is_editor => @is_editor,
          :templates => templates,
          :uploads => uploads,
          :editors => editors,
          :footer_links => settings.config["footer_links"],
          :csrf_token => Rack::Csrf.csrf_token(env)
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
    # We could use it to list all pages and their outstanding revisions, though.
    get "/pages" do
      @pages = Page.find_all(&:metadata_hash)
      liquid :list, :locals => {:pages => @pages, :page => {"name" => "pages"}}
    end

    post "/:page/history" do
      authorize! "/#{params[:page]}"
      head_id = params[:head]
      commit_display = 5
      commit_list = []
      Grit::Commit.find_all(GitWiki.repository, head_id, {:skip => 1}).each do |com|
        if com.message =~ /#{params[:page]}\z/
          commit_list << {"id" => com.id, "author" => com.author.to_s, "authored" => com.authored_date.strftime("%T on %m/%d/%Y"), 
                          "commited" => com.committed_date.strftime("%T on %m/%d/%Y"), "commiter" => com.committer.to_s,
                          "new_file" => com.diffs.first.new_file}
          break unless commit_list.length < commit_display
        end
      end
      json :result => commit_list
    end

    get "/:page/history" do
      authorize! "/#{params[:page]}"
      commit = GitWiki.repository.commits(params[:commit]).first
      if commit.diffs.first.new_file
        if /---.*?@@.*?@@\n/m =~ commit.diffs.first.diff
          data = $'.gsub(/\\.*?$/,'').gsub(/\+(.*?)$/, '\1')
          blob = BlobAlike.new commit.diffs.first.a_path, data
          @page = Page.new blob
        else
          @page = "HISTERROR"
        end
      else
        blob= commit.diffs.first.b_blob
        blob.name= commit.diffs.first.b_path
        @page = Page.new blob
      end
      template = @page.metadata["template"]
      template = templates.detect{|t| t["name"] == template } ? template.to_sym : :show
      liquid template, :locals => locals(@page, :header => header(@page, :for_approval => false))
    end

    get "/:page/edit" do
      authorize! "/#{params[:page]}"
      @page = Page.find_or_create(params[:page], username)

      ### Generate initial commits to display
      # potential for amortization (request in blocks) to be implemented
      commit_display = 5
      commit_list = []
      Grit::Commit.find_all(GitWiki.repository, 'master').each do |com|
        if com.message =~ /#{params[:page]}\z/
          commit_list << {"id" => com.id, "author" => com.author.to_s, "authored" => com.authored_date.strftime("%T on %m/%d/%Y"), 
                          "commited" => com.committed_date.strftime("%T on %m/%d/%Y"), "commiter" => com.committer.to_s, 
                          "new_file" => com.diffs.first.new_file}
          break unless commit_list.length < commit_display
        end
      end
      commit_list = nil if commit_list.empty?
      ###

      liquid :edit, :locals => locals(@page, :page_class => 'editor', :nocache => true,
          :mdown_examples => GitWiki.mdown_examples, :commit_list => commit_list)
    end
    
    get "/:page/approve/:username" do
      authorize! "/#{params[:page]}"
      redirect "/#{params[:page]}" unless forking_enabled? && @is_editor
      @page = Page.find_and_merge(params[:page], params[:username])
      liquid :edit, :locals => locals(@page, :page_class => 'editor', :nocache => true, 
          :mdown_examples => GitWiki.mdown_examples, :approving => true)
    end

    get '/download/:filename' do |filename|
      send_file "./public/uploads/#{filename}", :filename => filename
    end

    get "/:page/?:username?" do
      begin
        if params[:username]
          # An editor is looking at somebody else's changes to a page
          authorize! "/#{params[:page]}/#{params[:username]}"
          redirect "/#{params[:page]}" unless @is_editor && forking_enabled?
          for_approval = true
          @page = Page.find_and_merge(params[:page], params[:username])
        else
          # Get the user's unapproved version of the page, if logged in and it exists.
          # Otherwise, get the current approved version from the master branch
          @page = Page.find(params[:page], forking_enabled? && username)
        end
        template = @page.metadata["template"]
        template = templates.detect{|t| t["name"] == template } ? template.to_sym : :show
        # TODO: make header able to swap login/logout button to back button set in page metadata
        liquid template, :locals => locals(@page, :header => header(@page, :for_approval => for_approval))
      rescue PageNotFound => err
        empty_page = Page.empty_as_hash(err.name)
        liquid :error, :locals => locals(empty_page, :header => header(empty_page, :error => true), :error => err.to_hash)
      end
    end

    post "/:page" do
      authorize! "/#{params[:page]}"
      
      @page = Page.find_or_create(params[:page], username)
      new_metadata = @page.metadata.clone

      # Save and rename uploaded images
      if params[:body]
        new_image_hrefs = {}
        params.each do |key, param|
          if key =~ /image(\d*)/ && param[:filename]
            image_num = $1
            append = 0
            basename = File.basename(param[:filename], ".*").gsub(/[^A-Za-z0-9_-]/, '-') # sanitize basename
            ext = File.extname(param[:filename])
            continue unless [".jpg", ".png", ".jpeg", ".gif", ".bmp"].include?(ext) # validate extension
            filename = basename + ext
            # avoid overwriting an existing image with the same name
            while (File.exist?("./public/uploads/#{filename}")) do
              filename = "#{basename}-#{append += 1}#{ext}"
            end
            # Copy to final destination and memoize the href for this new image
            File.open("./public/uploads/#{filename}", "wb") { |f| f.write(param[:tempfile].read) }
            new_image_hrefs[image_num] = "/download/#{filename}"
          end
        end
        # Substitute temporary hrefs to newly uploaded images with their actual post-upload href
        # e.g., uploaded smiley.jpg as (1), then "![alt text](1)" --> "![alt text](smiley.jpg)"
        params[:body].gsub!(/!\[(.*?)\]\((\d*)\)/) {"![#{$1}](#{new_image_hrefs[$2]})"}
      end

      if @is_editor || !auth_enabled?
        Page::METADATA_FIELDS.each { |k, default| new_metadata[k] = params[k.to_sym] || default }
        @page.update_content(username, params[:body], new_metadata, params[:approving])
        notify_branch_author(@page, params[:approving], username) if params[:approving]
      elsif forking_enabled?
        # If the user is not an editor, the commit is made to a topic branch
        Page::NON_EDITOR_FIELDS.each { |k| new_metadata[k] = params[k.to_sym] if params[k.to_sym] }
        @page.branch_content(username, params[:body], new_metadata)
        notify_page_owner(@page, username)
      else
        error = {"name" => @page.name, "type" => "NotAnEditor"}
        liquid :error, :locals => locals(empty_page, :header => header(empty_page), :error => error)
      end
      
      # Run the other route (#call instead of #redirect avoids any caching)
      call env.merge("REQUEST_METHOD"=>"GET", "PATH_INFO" => "/#{@page}")
    end
  end
end

