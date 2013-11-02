require 'sinatra/base'
require 'rack-session-file'
require 'securerandom'
require 'mail'

module Sinatra
  module EmailAuth

    module Helpers
      def mail_domain
        settings.config["mail_domain"]
      end
      
      def username
        session[:authorized] && session[:username]
      end
      
      def authorized?
        !!username
      end
      
      def is_editor?
        editors = settings.config["editors"] || []
        !!username && editors.include?(username)
      end

      def authorize!(cancel_path = nil)
        unless authorized? or !settings.config["auth_enabled"]
          session[:auth_next_for] = request.path_info
          session[:auth_cancel] = cancel_path || request.path_info
          redirect "/login"
        end
      end

      def logout!
        session[:authorized] = false
      end
    end

    def self.registered(app)
      app.use Rack::Session::File, :expire_after => (60 * 60 * 24 * 90)   # 90 days

      app.helpers EmailAuth::Helpers

      app.get "/login" do
        auth_for = session[:auth_next_for] || "/"
        cancel = session[:auth_cancel] || "/"
        error = params[:error] || username
        liquid :login, :locals => {:error => error, :auth_for => auth_for, :auth_cancel => cancel, :domain => mail_domain}
      end

      app.post "/login" do
        auth_for = session[:auth_for] = params[:auth_for]
        cancel = session[:auth_cancel] || "/"
        
        if params[:email] =~ /^[\w._-]+$/
          session[:key] = SecureRandom.hex
          session[:username] = params[:email]
          session[:authorized] = false
          
          to_addr = "#{params[:email]}@mssm.edu"
          link = url("/verify_email?key=#{session[:key]}")
          
          # TODO: could maybe also embed cookie -> rack.session in here, so that
          #   if the email client opens the link in the wrong browser, we can fix that
          #   by switching to the right session anyway.
          #   But have to think about this.  It is CERTAINLY more dangerous since the email
          #   will then contain everything needed to compromise the session.
          mail = Mail.new do
            from     'ehhop.clinic@mssm.edu'
            to       to_addr
            subject  'EHHapp Authentication Request'
            body     sprintf(app.settings.config["mail_auth_body"], link)
          end
          
          begin
            mail.deliver!
          rescue
            mail.delivery_method :sendmail
            mail.deliver
          end
          
          liquid :login, :locals => {:auth_cancel => cancel, :sent => true}
        else
          liquid :login, :locals => {:error => 'username', :auth_for => auth_for, :auth_cancel => cancel, :domain => mail_domain}
        end
      end
      
      app.get "/verify_email" do
        # Check if the supplied key matches the one set in the server-side session
        if params[:key] == session[:key]
          session[:authorized] = true
          session[:just_auth] = true
          redirect session[:auth_for]
        else
          # The key didn't match!  Redirect back to the login page, so they can try again
          # Also display an error telling the user that the key didn't match and how to fix that
          redirect "/login?error=key"
        end
      end
      
      app.get "/logout" do
        session[:authorized] = false
        session[:username] = nil
        session[:just_auth] = true
        liquid :logout
      end
      
    end
  end

  register EmailAuth
end