require "sinatra/base"
require "sinatra/json"
require "rack/csrf"
require "grit"
require "yaml"
require "require_all"
require "rdiscount"
require "pp"
require "json"

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
    self.config.deep_merge!(YAML::load(File.open(config))) if File.file?(config)
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
  
  class UploadNotFound < PageNotFound
  end
 
  class App < Sinatra::Base
    set :app_file, __FILE__
    set :views, [settings.root + '/templates', settings.root + '/_layouts']

    register Sinatra::EmailAuth
    use Rack::Csrf, :raise => true, :skip => ['POST:/.*/history', 'POST:/login']
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
        Dir["./public/uploads/*"].sort_by{|f| File.stat(f).mtime }.map do |f| 
          {
            "name" => File.basename(f),
            "ext" => File.extname(f).gsub(/^\./, ''),
            "is_image" => [".jpg", ".png", ".jpeg", ".gif", ".bmp"].include?(File.extname(f))
          }
        end
      end
      
      def save_uploads(params)
        if params[:body]
          new_upload_hrefs = {}
          params.each do |key, param|
            next unless key =~ /upload(\d*)/ && param[:filename]
            upload_num = $1
            append = 0
            basename = File.basename(param[:filename], ".*").gsub(/[^A-Za-z0-9_-]/, '-') # sanitize basename
            ext = File.extname(param[:filename])
            # next unless [".jpg", ".png", ".jpeg", ".gif", ".bmp"].include?(ext) # validate extension
            filename = basename + ext
            # avoid overwriting an existing image with the same name
            while (File.exist?("./public/uploads/#{filename}")) do
              filename = "#{basename}-#{append += 1}#{ext}"
            end
            # Copy to final destination and memoize the href for this new image
            File.open("./public/uploads/#{filename}", "wb") { |f| f.write(param[:tempfile].read) }
            new_upload_hrefs[upload_num] = "/uploads/#{filename}"
          end
          # Substitute temporary hrefs to newly uploaded images with their actual post-upload href
          # e.g., uploaded smiley.jpg as (1), then "[alt text](1)" --> "[alt text](smiley.jpg)"
          params[:body].gsub!(/\[(.*?)\]\((\d*)\)/) {"[#{$1}](#{new_upload_hrefs[$2]})"}
        end
      end
      
      def header(page, and_these = {})
        liquid :header, :layout => false, :locals => locals(page, and_these)
      end
      
      def title(page_hash = nil)
        if page_hash && page_hash['name'] != GitWiki.homepage
          page_title = page_hash['metadata'] && page_hash['metadata']['title']
          page_title = page_title.to_s != '' ? page_title : page_hash['name']
          "#{settings.config['default_title']} - #{page_title}"
        else
          settings.config["default_title"]
        end
      end
            
      def locals(page, and_these = {})
        page_hash = page.to_hash
        {
          :just_auth => @just_auth, 
          :email => @email,
          :page => page_hash,
          :nocache => false,
          :is_editor => @is_editor,
          :templates => templates,
          :uploads => uploads,
          :editors => editors,
          :page_levels => Sinatra::EmailAuth::PAGE_LEVELS,
          :title => title(page_hash),
          :touch_icon => settings.config["touch_icon"],
          :footer_links => settings.config["footer_links"],
          :google_analytics => settings.config["google_analytics"],
          :csrf_token => Rack::Csrf.csrf_token(env)
        }.merge(and_these)
      end
      
    end  ### helpers

    before do
      content_type "text/html", :charset => "utf-8"
      @just_auth = !!session[:just_auth]
      session[:just_auth] = false
      @email = email
      @is_editor = is_editor?
      
      # A shim that ensures that pages with old metadata lacking domains has those fields emailified
      Page.add_extract_filter(:emailify_owner_author) do |metadata, body|
        metadata['owner'] = emailify metadata['owner']
        metadata['author'] = emailify metadata['author']
        [metadata, body]
      end
    end

    get "/" do
      redirect "/" + GitWiki.homepage
    end

    # NOTE: this route is a holdover from git-wiki and really isn't being used for anything, yet.
    # We could use it to list all pages and their outstanding revisions, though.
    get "/pages" do
      @pages = Page.find_all(&:metadata_hash)
      for_approval = false
      liquid :list, :layout => false, :locals => {:pages => @listpages, :page => {"name" => "pages"}}
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
      @page = Page.find_or_create(params[:page], email)

      ### Generate initial commits to display
      # potential for amortization (request in blocks) to be implemented
      commit_display = 5
      commit_list = []
      # Grit::Commit.find_all(GitWiki.repository, 'master').each do |com|
      #   if com.message =~ /#{params[:page]}\z/
      #     commit_list << {"id" => com.id, "author" => com.author.to_s, "authored" => com.authored_date.strftime("%T on %m/%d/%Y"), 
      #                     "commited" => com.committed_date.strftime("%T on %m/%d/%Y"), "commiter" => com.committer.to_s, 
      #                     "new_file" => com.diffs.first.new_file}
      #     break unless commit_list.length < commit_display
      #   end
      # end
      commit_list = nil if commit_list.empty?
      ###
      @page.body.force_encoding("utf-8")
      liquid :edit, :locals => locals(@page, :page_class => 'editor', :nocache => true,
          :mdown_examples => GitWiki.mdown_examples, :commit_list => commit_list)
    end
    
    get "/:page/approve/:email" do
      authorize! "/#{params[:page]}"
      redirect "/#{params[:page]}" unless forking_enabled? && @is_editor
      @page = Page.find_and_merge(params[:page], params[:email])
      liquid :edit, :locals => locals(@page, :page_class => 'editor', :nocache => true, 
          :mdown_examples => GitWiki.mdown_examples, :approving => true)
    end

    # TODO: deprecate this, we now write /uploads/ straight into the markdown
    # and all uploads live in public/uploads so the webserver can serve them
    get '/download/:filename' do |filename|
      redirect "/uploads/#{filename}"
    end
    
    # If an upload wasn't found, it will drop through to Sinatra and we have to handle it
    get '/uploads/:filename' do |filename|
      raise UploadNotFound.new(filename)
    end

    get "/:page/?:email??:format?" do
      if params[:email]
        # An editor is looking at somebody else's changes to a page
        authorize! "/#{params[:page]}/#{params[:email]}"
        redirect "/#{params[:page]}" unless @is_editor && forking_enabled?
        for_approval = true
        @page = Page.find_and_merge(params[:page], params[:email])
      else
        # Get the user's unapproved version of the page, if logged in and it exists.
        # Otherwise, get the current approved version from the master branch
        @page = Page.find(params[:page], forking_enabled? && email)
        enforce_page_access! @page
      end
      template = @page.metadata["template"]
      template = templates.detect{|t| t["name"] == template } ? template.to_sym : :show
      # TODO: make header able to swap login/logout button to back button set in page metadata
      if params[:format] == 'json'
		json :page => @page.to_json
      else
	      liquid template, :locals => locals(@page, :header => header(@page, :for_approval => for_approval))
      end
    end
    
    error PageNotFound do
      err = env['sinatra.error']
      status 200 if request.xhr?  # Suppress the 404 if jQuery Mobile fetched this with AJAX
      empty_page = Page.empty_as_hash(err.name)
      liquid :error, :locals => locals(empty_page, :header => header(empty_page, :error => true), :error => err.to_hash)
    end

    post "/:page" do
      authorize! "/#{params[:page]}"
      
      @page = Page.find_or_create(params[:page], email)
      new_metadata = @page.metadata.clone

      # Save and rename uploaded images and rewrite temporary href's in the body with the permanent ones
      save_uploads(params)

      if @is_editor || !auth_enabled?
        Page::METADATA_FIELDS.each { |k, default| new_metadata[k] = params[k.to_sym] || default }
        @page.update_content(email, params[:body], new_metadata, params[:approving])
        notify_branch_author(@page, params[:approving], email) if params[:approving]
      elsif forking_enabled?
        # If the user is not an editor, the commit is made to a topic branch
        Page::NON_EDITOR_FIELDS.each { |k| new_metadata[k] = params[k.to_sym] if params[k.to_sym] }
        @page.branch_content(email, params[:body], new_metadata)
        notify_page_owner(@page, email)
      else
        error = {"name" => @page.name, "type" => "NotAnEditor"}
        liquid :error, :locals => locals(empty_page, :header => header(empty_page), :error => error)
      end
      
      # Run the other route (#call instead of #redirect avoids any caching)
      call env.merge("REQUEST_METHOD"=>"GET", "PATH_INFO" => "/#{@page}")
    end
  end
end

