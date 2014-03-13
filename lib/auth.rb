require 'sinatra/base'
require 'rack-session-file'
require 'securerandom'
require 'mail'
require 'tempfile'
require 'pstore'

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

    module Helpers

      # page levels
      def page_levels
        ["Public", "Authorized Users Only"]
      end

      def accessible?(page)
        true
        false if page.metadata["accessibility"] == "Authorized Users Only" and !authorized?
      end

      def accessible!(page)
        unless accessible?(page) or !auth_enabled?
          session[:auth_next_for] = request.path_info
          session[:auth_cancel] = cancel_path || request.path_info
          redirect "/login"
        end
      end
      ### page levels

      def auth_settings
        settings.config["auth"] || {}
      end
      
      def default_title; settings.config["default_title"]; end
      
      def auth_enabled?
        !!auth_settings["enabled"]
      end
      
      def auth_store
        return EmailAuth.store if EmailAuth.store
        store = EmailAuth.store = PStore.new(File.expand_path(auth_settings["pstore_filename"], Dir.tmpdir))
        store.transaction do
          store[:lockouts] ||= {}
          store[:keys_issued] ||= {}
          store[:failures] ||= {}
        end
        store
      end
      
      def username
        session[:authorized] && session[:username]
      end
      
      def authorized?
        !!username
      end
      
      def editors
        auth_settings["editors"] or raise "You must specify some editors of this wiki in config.yaml!"
      end
      
      def is_editor?
        !!username && editors.include?(username)
      end
      
      def forking_enabled?
        !!auth_settings["non_editor_forking"]
      end
      
      def plausible_username?(username)
        !!username.match(auth_settings["username_regexp"] || /^[\w_-]+(\.[\w_-]+)*$/)
      end

      def authorize!(cancel_path = nil)
        unless authorized? or !auth_enabled?
          session[:auth_next_for] = request.path_info
          session[:auth_cancel] = cancel_path || request.path_info
          redirect "/login"
        end
      end
      
      def issue_key(username)
        # Check that a key wasn't issued too recently in the past.
        auth_store.transaction do
          key_issued = auth_store[:keys_issued][username]
          return false if key_issued && key_issued > (Time.now - auth_settings["key_issue_interval"])
        
          # Issue the key.  It is a random 6-digit number with no leading 0's.
          session[:key] = (SecureRandom.random_number * 900000 + 100000).round.to_s
          auth_store[:keys_issued][username] = Time.now
        end
        session[:username] = username
        session[:authorized] = false
        
        mail = Mail.new
        mail.from = auth_settings["mail_from"]
        mail.to = "#{username}@#{auth_settings["mail_domain"]}"
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
        mail.to = "#{page.metadata["owner"] || editors.first}@#{auth_settings["mail_domain"]}"
        mail.subject = "#{default_title} changes submitted by #{author} for #{page.name}"
        mail.body = sprintf(settings.config["fork_notify_message"], author, version_url)
        mail.return_path = auth_settings["mail_bounce"]   # Control where bounces go
        mail.deliver_and_fallback!
      end
      
      def notify_branch_author(page, author, editor)
        mail = Mail.new
        mail.from = auth_settings["mail_from"]
        mail.to = "#{author}@#{auth_settings["mail_domain"]}"
        mail.subject = "#{default_title} changes accepted by #{editor} for #{page.name}"
        mail.body = sprintf(settings.config["fork_accepted_message"], editor, url("/#{page.name}"))
        mail.return_path = auth_settings["mail_bounce"]   # Control where bounces go
        mail.deliver_and_fallback!
      end
      
      # Check that the user is not in within a lockout window (i.e., currently locked out)
      def locked_out?(username = nil)
        auth_store.transaction do
          locked_out_until = auth_store[:lockouts][username || session[:username]]
          !!(locked_out_until && locked_out_until > Time.now)
        end
      end
      
      # Check that the key issued for a user has not expired
      def key_expired?(username = nil)
        auth_store.transaction do
          key_issued = auth_store[:keys_issued][username || session[:username]]
          !key_issued || Time.now - key_issued > auth_settings["key_expiration_interval"]
        end
      end
      
      def invalid_key?(key, username = nil)
        username ||= session[:username]
        return "session_problem" if !username
        return "locked_out" if locked_out?(username)
        return "key_expired" if key_expired?(username)
        auth_store.transaction do
          if key != session[:key] # Check if the key matches the one stored in the session.
            # Shift the time into the failures array for that user
            (auth_store[:failures][username] ||= []).unshift(Time.now)
            # Trim the failures array to max_failures elements
            auth_store[:failures][username] = auth_store[:failures][username].first(auth_settings["max_failures"])
            # If the last is within max_failures_interval of now, initiate a lockout
            if auth_store[:failures][username].last > Time.now - auth_settings["max_failures_interval"]
              auth_store[:lockouts][username] = Time.now + auth_settings["lockout_interval"]
            end
            "invalid_key"
          else
            # Clear the key issued time so the user can logout and re-issue a key right away
            auth_store[:keys_issued][username] = nil
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
        session[:username] = nil
        session[:just_auth] = true
      end
      
      def footer_links; settings.config["footer_links"]; end
      
      def auth_locals(and_these = {})
        {
          :auth_enabled => auth_enabled?,
          :nocache => true,
          :domain => auth_settings["mail_domain"],
          :max_failures => auth_settings["max_failures"],
          :sent_to => session[:username],
          :just_auth => session[:just_auth],
          :footer_links => footer_links
        }.merge(and_these)
      end
    end

    def self.registered(app)
      app.use Rack::Session::File, :expire_after => (60 * 60 * 24 * 90)   # 90 days

      app.helpers EmailAuth::Helpers

      app.get "/login" do
        cancel = session[:auth_cancel] || "/"
        error = params[:error]
        sent = false
        if !error && session[:key] && session[:username] && !authorized?
          # We've sent an email with the key, display a numeric input to enter it
          if locked_out? then error = "locked_out"
          elsif key_expired? then error = "key_expired"; end
          sent = !error
        else
          error ||= username   # Warn if we are already logged in
          auth_for = session[:auth_next_for] || "/"
        end
        liquid :login, :locals => auth_locals(:error => error, :auth_for => auth_for, :auth_cancel => cancel, :sent => sent)
      end

      app.post "/login" do
        auth_for = nil
        cancel = session[:auth_cancel] || "/"
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
            error = "implausible_username" unless plausible_username?(params[:email])
            error = "locked_out" if locked_out?(params[:email])
            unless error
              # Try to issue; if we can't, it's because a key was issued too recently
              error = "too_soon" unless issue_key(params[:email])
              sent = !error
            end
          end
        end
        liquid :login, :locals => auth_locals(:error => error, :auth_cancel => cancel, :auth_for => auth_for, :sent => sent)
      end
      
      app.get "/logout" do
        logout! if params[:confirm]
        liquid :logout, :locals => {:footer_links => footer_links, :confirmed => !!params[:confirm]}
      end
      
    end
  end

  # Tell Sinatra that the EmailAuth module exists.
  register EmailAuth
end
