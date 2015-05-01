require 'rubygems'
require 'innate'
require 'rack/csrf'

require './app'

Innate.start do |m|
  m.use Rack::ShowExceptions
  m.use Rack::Session::Cookie
  m.use Rack::Csrf, :raise => true
  m.innate
end
