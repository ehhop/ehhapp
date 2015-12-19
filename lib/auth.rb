require 'sinatra/base'
require 'rack-session-file'
require 'securerandom'
require 'mail'
require 'tempfile'
require 'pstore'
require 'fileutils'
require_relative 'page'

# A quick monkey-patch to always try sending mails first via local SMTP and then sendmail.
module Mail
  class Message
    def deliver_and_fallback!
      begin
        deliver!
      rescue
        delivery_method :sendmail
        deliver
      end
    end
  end
end

module Sinatra
  
  # A module that supports all email-related authentication functionality of the EHHapp
  # It is backed by rack-session-file and a PStore for lockouts, key issue times, etc.
  module EmailAuth
    
    class << self
      attr_accessor :store
    end
    
    # This is a variable that will be linked to the PStore to contain lockouts, key issue times, etc.
    # See Helpers#auth_store for the initialization code
    self.store = nil
    
    # Levels of visibility that can be set for each page.
    PAGE_LEVELS ||= {"public" => "Public", "private" => "Logged-in users only"}

    module Helpers
      
      def auth_settings
        settings.config["auth"] || {}
      end
      
      def default_title; settings.config["default_title"]; end
      
      def auth_enabled?
        !!auth_settings["enabled"]
      end
      
      def auth_store
        return EmailAuth.store if EmailAuth.store && auth_store_valid?
        # Initialize the store if it hasn't been opened already or it is invalid
        store = EmailAuth.store = PStore.new(File.expand_path(auth_settings["pstore_filename"], Dir.tmpdir))
        store.transaction do
          store[:lockouts] ||= {}
          store[:keys_issued] ||= {}
          store[:failures] ||= {}
        end
        store
      end
      
      def auth_store_valid?
        !!(EmailAuth.store.transaction {|as| as[:lockouts] && as[:keys_issued] && as[:failures] })
      end
      
      def email
        session[:authorized] && session[:email]
      end
      
      def authorized?
        !!email
      end
      
      def editors
        raise "You must specify some editors of this wiki in config.yaml!" unless auth_settings["editors"]
        auth_settings["editors"].map{|editor| emailify editor } # in case they were configured as usernames
      end
      
      def is_editor?
        !!email && editors.include?(email)
      end
      
      def forking_enabled?
        !!auth_settings["non_editor_forking"]
      end
      
      def plausible_username?(username)
        !!username.match(auth_settings["username_regexp"] || /^[\w_-]+(\.[\w_-]+)*$/)
      end

      def plausible_domain?(domain)
        auth_settings["mail_domain"].include? domain
      end

      def plausible_email?(email)
        username, domain = email.split('@', 2)
        plausible_username?(username) and plausible_domain?(domain)
      end

      # For legacy purposes (before @example.com was recorded for owners and authors)
      # In this case, the first configured mail_domain is assumed for any username
      def emailify(something)
        return something if something.nil?
        if plausible_email?(something) 
          email = something
        else
          email = something + '@' + auth_settings["mail_domain"].first
        end
        email
      end

      # Is the current viewer logged in?  If not, redirect to the login screen
      def authorize!(cancel_path = nil)
        unless authorized? or !auth_enabled?
          session[:auth_next_for] = request.path_info
          session[:auth_reason] = nil
          session[:auth_cancel] = cancel_path || request.path_info
          redirect "/login"
        end
      end
      
      def issue_key(email)
        # Check that a key wasn't issued too recently in the past.
        auth_store.transaction do |astore|
          key_issued = astore[:keys_issued][email]
          return false if key_issued && key_issued > (Time.now - auth_settings["key_issue_interval"])
        
          # Issue the key.  It is a random 6-digit number with no leading 0's.
          session[:key] = (SecureRandom.random_number * 900000 + 100000).round.to_s
          astore[:keys_issued][email] = Time.now
        end
        session[:email] = email
        session[:authorized] = false
        
        mail = Mail.new
        mail.from = auth_settings["mail_from"]
        mail.to = email
        mail.subject = "#{default_title} Authentication Request"
        mail.body = sprintf(auth_settings["mail_body"], session[:key])
        mail.return_path = auth_settings["mail_bounce"]   # Control where bounces go
        mail.deliver_and_fallback!
        true
      end
      
      def notify_page_owner(page, author)
        version_url = url("/#{page.name}/#{author}")
        mail = Mail.new
        mail.from = auth_settings["mail_from"]
        owner_email = emailify(page.metadata["owner"])
        mail.to = "#{owner_email || editors.first}"
        mail.subject = "#{default_title} changes submitted by #{author} for #{page.name}"
        mail.body = sprintf(settings.config["fork_notify_message"], author, version_url)
        mail.return_path = auth_settings["mail_bounce"]   # Control where bounces go
        mail.deliver_and_fallback!
      end
      
      def notify_branch_author(page, author, editor)
        mail = Mail.new
        mail.from = auth_settings["mail_from"]
        mail.to = emailify(author)
        mail.subject = "#{default_title} changes accepted by #{editor} for #{page.name}"
        mail.body = sprintf(settings.config["fork_accepted_message"], editor, url("/#{page.name}"))
        mail.return_path = auth_settings["mail_bounce"]   # Control where bounces go
        mail.deliver_and_fallback!
      end
      
      # Check that the user is not in within a lockout window (i.e., currently locked out)
      def locked_out?(email = nil)
        auth_store.transaction do |astore|
          locked_out_until = astore[:lockouts][email || session[:email]]
          !!(locked_out_until && locked_out_until > Time.now)
        end
      end
      
      # Check that the key issued for a user has not expired
      def key_expired?(email = nil)
        auth_store.transaction do |astore|
          key_issued = astore[:keys_issued][email || session[:email]]
          !key_issued || Time.now - key_issued > auth_settings["key_expiration_interval"]
        end
      end
      
      def invalid_key?(key, email = nil)
        email ||= session[:email]
        return "session_problem" if !email
        return "locked_out" if locked_out?(email)
        return "key_expired" if key_expired?(email)
        auth_store.transaction do |astore|
          if key != session[:key] # Check if the key matches the one stored in the session.
            # Shift the time into the failures array for that user
            (astore[:failures][email] ||= []).unshift(Time.now)
            # Trim the failures array to max_failures elements
            astore[:failures][email] = astore[:failures][email].first(auth_settings["max_failures"])
            # If the last is within max_failures_interval of now, initiate a lockout
            if astore[:failures][email].last > Time.now - auth_settings["max_failures_interval"]
              astore[:lockouts][email] = Time.now + auth_settings["lockout_interval"]
            end
            "invalid_key"
          else
            # Clear the key issued time so the user can logout and re-issue a key right away
            astore[:keys_issued][email] = nil
            false
          end
        end
      end
      
      def login!
        session[:authorized] = true
        session[:just_auth] = true
      end
      
      def logout!
        session[:authorized] = false
        session[:email] = nil
        session[:just_auth] = true
      end
      
      def footer_links; settings.config["footer_links"]; end
      
      def auth_locals(and_these = {})
        {
          :auth_enabled => auth_enabled?,
          :auth_reason => session[:auth_reason],
          :nocache => true,
          :domains => auth_settings["mail_domain"],
          :max_failures => auth_settings["max_failures"],
          :sent_to => session[:email],
          :just_auth => session[:just_auth],
          :title => "#{default_title} - Login",
          :footer_links => footer_links
        }.merge(and_these)
      end
      
      ### Helpers for page visibility
      ### Pages can be private, which means only logged in users can view them.
      
      # Does the current viewer have the ability to see the page?
      def accessible?(page)
        authorized? || page.metadata["accessibility"] != "private"
      end

      # If the current viewer cannot view the page, redirect to the login screen.
      def enforce_page_access!(page)
        unless accessible?(page) or !auth_enabled?
          session[:auth_next_for] = request.path_info
          session[:auth_reason] = "You must login to view this page."
          session[:auth_cancel] = nil
          redirect "/login"
        end
      end
      
    end  ### end module Helpers
    

    # define routes for EmailAuth
    def self.registered(app)
      app.helpers EmailAuth::Helpers
      
      session_store = "#{Dir.tmpdir}/rack-sessions"
      FileUtils.mkdir_p session_store
      
      app.use Rack::Session::File, :expire_after => (60 * 60 * 24 * 90), :storage => session_store

      app.get "/login" do
        cancel = session[:auth_cancel] || "/"
        error = params[:error]
        sent = false
        if !error && session[:key] && session[:email] && !authorized?
          # We've sent an email with the key, display a numeric input to enter it
          if locked_out? then error = "locked_out"
          elsif key_expired? then error = "key_expired"; end
          sent = !error
        else
          error ||= email   # Warn if we are already logged in
          auth_for = session[:auth_next_for] || "/"
        end
        liquid :login, :locals => auth_locals(:error => error, :auth_for => auth_for, :auth_cancel => cancel, :sent => sent)
      end

      app.post "/login" do
        auth_for = nil
        cancel = session[:auth_cancel]
        error = nil
        sent = false
        
        if auth_enabled?
          if params[:key]
            # We have received a key
            error = invalid_key?(params[:key])
            sent = true unless error == "locked_out"
            login! && redirect(session[:auth_for]) unless error
          else
            # We are trying to send a key to an email address
            auth_for = session[:auth_for] = params[:auth_for]
            error = "implausible_username" unless plausible_username?(params[:username])
            error = "implausible_domain" unless plausible_domain?(params[:domain])
            email = params[:username].downcase() +'@'+ params[:domain].downcase()
            error = "locked_out" if locked_out?(email)
            unless error
              # Try to issue; if we can't, it's because a key was issued too recently
              error = "too_soon" unless issue_key(email)
              sent = !error
            end
          end
        end
        liquid :login, :locals => auth_locals(:error => error, :auth_cancel => cancel, :auth_for => auth_for, :sent => sent)
      end
      
      app.get "/logout" do
        logout! if params[:confirm]
        title = "#{default_title} - Logout"
        liquid :logout, :locals => {:footer_links => footer_links, :confirmed => !!params[:confirm], :title => title}
      end
      
    end
  end

  # Tell Sinatra that the EmailAuth module exists.
  register EmailAuth
end
