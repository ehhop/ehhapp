require "nokogiri"
require_relative "core_ext"

module GitWiki

  class TemplateTransformation
    
    def initialize(html, page=nil)
      @html = html
      @nk = Nokogiri::HTML.fragment(html, "UTF-8")
      @page = page
    end
  
    def transform; @html; end
    
    def self.example(mdown, html)
      @examples ||= []
      @examples << {"mdown" => mdown, "html" => html}
    end
    
    class << self
      attr_accessor :examples
    end
    
  end

  require_all "templates/*.rb"

end