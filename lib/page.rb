require "grit"
require "rdiscount"
require "lockfile"
require_relative "core_ext"
require "json"

module GitWiki

  class Page
    METADATA_FIELDS = {
      'template' => 'unstyled',
      'title' => '',
      'author' => nil,
      'last_modified' => nil,
      'owner' => nil,
      'backlink' => nil,
      'accessibility' => 'Public'
    }
    
    # Which metadata is safe for non-editors to change?
    NON_EDITOR_FIELDS = ['template', 'title', 'backlink']
    
    EMPTY_AS_HASH = {
      "name" => "",
      "body" => "",
      "on_branch" => false,
      "metadata" => {},
      "to_html" => "",
      "new" => true,
      "conflicts" => false
    }
    
    @extract_filters = {}
    
    def self.valid_name?(name)
      !!(name =~ /^[\w-]+$/)
    end
  
    def self.find_all
      return [] if repository.tree.contents.empty?
      repository.tree.contents.collect do |blob|
        if block_given? then yield new(blob); else new(blob); end
      end
    end

    def self.find(name, author = nil)
      raise InvalidPageName.new(name) unless valid_name?(name)
      page_blob, on_branch = find_blob(name, author)
      raise PageNotFound.new(name) unless page_blob
      new(page_blob, on_branch)
    end
    
    def self.find_and_merge(name, author = nil)
      page_blob_other, on_branch = find_blob(name, author)
      raise BranchNotFound.new(name) unless on_branch
      raise PageNotFound.new(name) unless page_blob_other
      page_blob, foo = find_blob(name)
      if page_blob
        page = new(page_blob, on_branch)
        page.merged_with(author, page_blob_other)
      else
        page = new(page_blob_other, on_branch)
      end
    end

    def self.find_or_create(name, author = nil)
      find(name, author)
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
    
    def self.repo_lock(&block)
      path = File.join(repository.working_dir, ".lockfile")
      lockfile = Lockfile.new(path, {:max_age => 60, :suspend => 2})
      if block_given? then lockfile.lock &block; else lockfile; end
    end

    def self.extension
      GitWiki.extension || raise
    end
    
    def self.empty_as_hash(name)
      name = "" unless valid_name?(name)
      EMPTY_AS_HASH.clone.merge({"name" => name, "metadata" => METADATA_FIELDS.clone})
    end
    
    def self.get_template(name)
      GitWiki.const_get(name.to_classname)
    end
    
    def self.create_blob_for(page_name, data = "")
      # Note that Grit::Blob.create does not save anything to the repo
      # The blob is "unbaked" and only exists within memory
      Grit::Blob.create(repository, {
        :name => page_name + extension,
        :data => data
      })
    end

    def self.find_blob(page_name, author = nil)
      # If the author was specified, look for the blob in the author's topic branch first
      blob = repository.tree("#{author}/#{page_name}")/(page_name + extension) if author
      on_branch = "#{author}/#{page_name}" if blob
      # If we didn't find the blob on the author's topic branch, get it from the master branch
      blob ||= repository.tree/(page_name + extension)
      [blob, on_branch]
    end
    private_class_method :find_blob
    
    # You can define filters that are run on a Page's metadata and body after instantiating
    # from a Grit::Blob.  They can perform additional cleaning or modification.
    # See Page#extract_front_matter below.  GitWiki uses this to clean metadata in legacy formats.
    def self.add_extract_filter(filter_name, &filter)
      @extract_filters[filter_name] = filter
    end
    class << self; attr_reader :extract_filters; end

    # =================================================
    # = Now we define the instance methods for a Page =
    # =================================================

    attr_reader :metadata, :body, :conflicts
    
    def initialize(blob, on_branch = nil, conflicts = false)
      @blob = blob
      raise InvalidPageName.new(name) unless self.class.valid_name?(name)
      @on_branch = on_branch
      @conflicts = conflicts
      @metadata, @body = extract_front_matter
    end
    
    def to_html
      # Translate to HTML
      html = RDiscount.new(body).to_html
      # Apply appropriate post-translational modifications based on specified template
      begin
        if metadata["template"]
          html = self.class.get_template(metadata["template"]).new(html, self).transform
        end
      rescue NameError; end
      html
    end

    def to_json
      # Translate to json
      json = {:metadata => metadata, :body => body.force_encoding('utf-8').to_json}
      json
    end

    def to_s
      name
    end
  
    def to_hash
      EMPTY_AS_HASH.clone.merge({
        "name" => name,
        "body" => body,
        "on_branch" => on_branch?,
        "metadata" => metadata,
        "to_html" => to_html,
        "new" => new?,
        "conflicts" => conflicts
      })
    end
    
    def metadata_hash
      {
        "name" => name,
        "metadata" => metadata
      }
    end

    def new?
      @blob.id.nil? && @blob.data == ""
    end

    def name
      @blob.name.gsub(/#{File.extname(@blob.name)}$/, '')
    end

    def content
      @blob.data
    end
    
    def on_branch?
      !!@on_branch
    end
  
    # Commits the new content to the "master" branch
    # If other_author is specified, this becomes a merge commit and that author's branch is deleted
    # At the end of this operation, the working directory will reflect HEAD of the master branch
    def update_content(author, new_body, new_metadata = {}, other_author = nil)
      new_content = prepare_new_content(author, new_body, new_metadata)
      return if new_content == content && !merging
      
      # LOCK during this operation, which changes the working tree and index
      self.class.repo_lock do
        if other_author && !other_author.empty?
          merge_and_commit!(author, new_content, other_author)
        else 
          commit!(author, new_content)
        end
      end # ... UNLOCK
      
      @metadata, @body = extract_front_matter
    end
    
    # Creates a new branch of this page's content for this author, if it doesn't already exist
    # It is named after the author and the page name, e.g. "alex.jones/page_name"
    # Then, commits the content to this branch
    def branch_content(author, new_body, new_metadata = {})
      new_content = prepare_new_content(author, new_body, new_metadata)
      return if new_content == content
      
      # LOCK during this operation, which could be affected by the working tree & index
      self.class.repo_lock do branch_and_commit!(author, new_content); end
    end
    
    # Mutates the page object into a previewed merge between master and the author's branch
    def merged_with(author, other_blob)
      branch_name = "#{author}/#{name}"
      git = self.class.repository.git
      merged_body = nil
      
      # LOCK during this operation, which changes the working tree and index
      self.class.repo_lock do
        Dir.chdir(self.class.repository.working_dir) do
          # Since this process overwrites files in the working tree, and messes with the index...
          begin
            merge_result = git.merge({:no_ff => true, :no_commit => true}, branch_name)
            merged_body = File.read(file_name).sub(/[\s\S]*\n---[ \t]*\n/, '')
          ensure
            # we want to ensure that they are returned to their previous state
            git.reset(:hard => true)
          end
        end
      end  # ... UNLOCK
      
      other_metadata, other_body = extract_front_matter(other_blob.data)
      if Grit::Merge.new(merged_body).conflicts == 0
        new_content = prepare_new_content(author, merged_body, other_metadata, false)
        initialize(self.class.create_blob_for(name, new_content), branch_name)
      else
        new_content = prepare_new_content(author, other_body, other_metadata, false)
        initialize(self.class.create_blob_for(name, new_content), branch_name, true)
      end
      
      self
    end

    # Metadata is stored as a YAML file at the beginning of each page --
    # kind of like YAML front matter in Jekyll.
    # This function extracts the YAML front matter into a [metadata, page_content] pair.
    # If there is no YAML front matter, we supply the default metadata values.
    # We also pass the metadata and body through previously defined extract_filters
    #   (see Page.add_extract_filter above) which can clean or modify their contents.
    private
    def extract_front_matter(from = nil)
      from ||= content
      if from =~ /\A(---[ \t]*\n.*?\n?)^(---[ \t]*$\n?)/m
        metadata, body = [YAML.load($1), $']
      else
        metadata, body = [METADATA_FIELDS.clone, from]
      end
      self.class.extract_filters.each do |key, filter|
        metadata, body = filter.call(metadata, body)
      end
      [metadata, body]
    end
    
    # Package metadata and body into one string of page content, ready to be committed.
    def prepare_new_content(author, new_body, new_metadata, update_last_modified = true)
      new_metadata["last_modified"] = Time.now if update_last_modified
      new_metadata["author"] = author
      "#{ new_metadata.to_yaml }--- \n#{ new_body }"
    end

    # TODO: Test if this method works for the first commit in an empty repo
    # Commits new_content to the master branch without using the working directory
    def commit!(author, new_content)
      @on_branch = nil
      repo = self.class.repository
      index = repo.index
      index.read_tree("master")
      index.add(name + self.class.extension, new_content)
      parents = [repo.commit("master")].compact
      index.commit(commit_message(author), parents, actor(author), nil, "master")
      initialize(repo.tree/(@blob.name)) # Reinitialize from the committed blob
      # Since this changes the master branch, bring the working directory up to speed
      Dir.chdir(repo.working_dir) { repo.git.reset(:hard => true) }
    end
    
    # TODO: Test if this method works for the first commit in an empty repo
    # Commits new_content to a topic branch named after the author and page name
    # e.g. "alex.jones/this_page"
    def branch_and_commit!(author, new_content)
      @on_branch = "#{author}/#{name}"
      repo = self.class.repository
      index = repo.index
      parents = [repo.commit(@on_branch) || repo.commit("master")].compact
      index.read_tree(repo.commit(@on_branch) ? @on_branch : "master")
      index.add(name + self.class.extension, new_content)
      index.commit(commit_message(author, true), parents, actor(author), nil, @on_branch)
      # Reinitialize this Page object from the committed blob
      initialize(repo.tree(@on_branch)/(name + self.class.extension), @on_branch)
    end
    
    # Commits new_content to the master branch while merging in another author's topic branch
    def merge_and_commit!(author, new_content, other_author)
      repo = self.class.repository
      branch_name = "#{other_author}/#{name}"
      raise BranchNotFound unless repo.commit(branch_name) && repo.commit("master")
      index = repo.index
      parents = [repo.commit("master"), repo.commit(branch_name)]
      index.read_tree("master")
      index.add(name + self.class.extension, new_content)
      index.commit(commit_message(author, other_author, true), parents, actor(author), nil, "master")
      # Now that it is merged, we can delete the author's topic branch.
      repo.git.branch({}, "-d", branch_name)
      # Reinitialize this Page object from the committed blob
      initialize(repo.tree/(name + self.class.extension))
      # Since this changes the master branch, bring the working directory up to speed
      Dir.chdir(repo.working_dir) { repo.git.reset(:hard => true) }
    end

    # What's the full file name pointing to this page's content in the working tree?
    def file_name
      File.join(self.class.repository.working_dir, name + self.class.extension)
    end
    
    # Turns an author's username into a Grit::Actor for the purposes of committing
    def actor(author)
      author ? Grit::Actor.new(author, author) : nil
    end

    # Creates a standardized commit message for each kind of action
    def commit_message(author, personal_branch = false, merging = false)
      if personal_branch
        # The author is working on his own branch, not master
        if merging then "#{author} merged edits by #{personal_branch} into #{name}"
        else "Proposed edits to #{name} by #{author}"; end
      else
        "#{author} #{new? ? 'created' : 'updated'} #{name}"
      end
    end
  end

end
