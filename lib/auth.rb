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
      
      def authorized?
        session[:authorized]
      end

      def authorize!
        unless authorized? or !settings.config["auth_enabled"]
          session[:back] = request.path_info
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
        back = session[:back] || "/"
        liquid :login, :locals => {:back => back, :domain => mail_domain}
      end

      app.post "/login" do
        if params[:email] =~ /^[\w._-]+$/
          session[:key] = SecureRandom.hex
          mail = Mail.new do
            from     'ehhop.clinic@mssm.edu'
            to       "#{params[:email]}@mssm.edu"
            subject  'EHHapp Authentication Request'
            body     mail_body
          end
          
          # TODO: send email with link to verify_email?key=...
          # TODO: Show a message that the link was sent.
        else
          # TODO: display error page saying that wasn't a valid address.
          liquid :login, :locals => {:back => params[:back], :domain => mail_domain, :error => true}
        end
      end
      
      app.get "/verify_email" do
        # TODO: take params[:key], check if it matches the session, etc. ...
        #       If it does, set session[:authorized] to true
        #       If not, display a gentle error page and redirect to the login page.
        # TODO: If we wanted to be fancy we'd not care about an existing session
        #       and use an HMAC within the key to create it from scratch.  But this
        #       is prone to nasty crypto bugs
      end
    end
  end

  register EmailAuth
end