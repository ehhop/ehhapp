require 'sinatra/base'
require 'rack-session-file'
require 'securerandom'
require 'mail'

module Sinatra
  module EmailAuth
    
    class << self
      attr_accessor :lockouts, :keys_issued, :failures
    end
    
    # In a smarter, more scalable world, these would have to live somewhere where multiple
    # instances of this program could access it without worry.  Perhaps in a Tokyo Cabinet.
    self.lockouts = {}
    self.keys_issued = {}
    self.failures = {}

    module Helpers
      def auth_settings
        settings.config["auth"] || {}
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

      def authorize!(cancel_path = nil)
        unless authorized? or !auth_settings["enabled"]
          session[:auth_next_for] = request.path_info
          session[:auth_cancel] = cancel_path || request.path_info
          redirect "/login"
        end
      end
      
      def issue_key(username)
        # Check that a key wasn't issued too recently in the past.
        key_issued = EmailAuth.keys_issued[username]
        return false if key_issued && key_issued > (Time.now - auth_settings["key_issue_interval"])
        
        # Issue the key.  It is a random 6-digit number with no leading 0's.
        session[:key] = (SecureRandom.random_number * 900000 + 100000).round.to_s
        EmailAuth.keys_issued[username] = Time.now
        session[:username] = username
        session[:authorized] = false
        
        mail = Mail.new
        mail.from = auth_settings["mail_from"]
        mail.to = "#{username}@#{auth_settings["mail_domain"]}"
        mail.subject = "EHHapp Authentication Request"
        mail.body = sprintf(auth_settings["mail_body"], session[:key])
        mail.return_path = auth_settings["mail_bounce"]   # Control where bounces go
        
        begin
          mail.deliver!
        rescue
          mail.delivery_method :sendmail
          mail.deliver
        end
        
        true
      end
      
      # Check that the user is not in within a lockout window (i.e., currently locked out)
      def locked_out?(username = nil)
        locked_out_until = EmailAuth.lockouts[username || session[:username]]
        !!(locked_out_until && locked_out_until > Time.now)
      end
      
      # Check that the key issued for a user has not expired
      def key_expired?(username = nil)
        key_issued = EmailAuth.keys_issued[username || session[:username]]
        !key_issued || Time.now - key_issued > auth_settings["key_expiration_interval"]
      end
      
      def invalid_key?(key, username = nil)
        username ||= session[:username]
        return "session_problem" if !username
        return "locked_out" if locked_out?(username)
        return "key_expired" if key_expired?(username)
        if key != session[:key] # Check if the key matches the one stored in the session.
          # Shift the time into the failures array for that user
          (EmailAuth.failures[username] ||= []).unshift(Time.now)
          # Trim the failures array to max_failures elements
          EmailAuth.failures[username] = EmailAuth.failures[username].first(auth_settings["max_failures"])
          # If the last is within max_failures_interval of now, initiate a lockout
          if EmailAuth.failures[username].last > Time.now - auth_settings["max_failures_interval"]
            EmailAuth.lockouts[username] = Time.now + auth_settings["lockout_interval"]
          end
          "invalid_key"
        else
          # Clear the key issued time so the user can logout and re-issue a key right away
          EmailAuth.keys_issued[username] = nil
          false
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
      
      def auth_locals(and_these = {})
        {
          :nocache => true,
          :domain => auth_settings["mail_domain"],
          :max_failures => auth_settings["max_failures"],
          :sent_to => session[:username],
          :just_auth => session[:just_auth]
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
          if key_expired? then error = "key_expired"
          else
            error = "locked_out" if locked_out?
            sent = true
          end
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
        
        if params[:key]
          # We have received a key
          sent = true
          error = invalid_key?(params[:key])
          login! && redirect(session[:auth_for]) unless error
        else
          # We are trying to send a key to an email address
          auth_for = session[:auth_for] = params[:auth_for]
          error = "implausible_username" unless params[:email] =~ /^[\w._-]+$/
          unless error
            # Try to issue; if we can't, it's because it's too soon to be able to issue a new key for this user
            error = "too_soon" unless issue_key(params[:email])
            sent = !error
          end
        end
        liquid :login, :locals => auth_locals(:error => error, :auth_cancel => cancel, :auth_for => auth_for, :sent => sent)
      end
      
      # app.get "/verify_email" do
      #   # Check if the supplied key matches the one set in the server-side session
      #   if params[:key] == session[:key]
      #     login!
      #   else
      #     # The key didn't match!  Redirect back to the login page, so they can try again
      #     # Also display an error telling the user that the key didn't match and how to fix that
      #     redirect "/login?error=invalid_key"
      #   end
      # end
      
      app.get "/logout" do
        logout!
        liquid :logout
      end
      
    end
  end

  register EmailAuth
end