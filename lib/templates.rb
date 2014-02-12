require "nokogiri"
require_relative "core_ext"

module GitWiki

  class TemplateTransformation
    
    def initialize(html, page=nil)
      @nk = Nokogiri::HTML.fragment(html, "UTF-8")
      
      # Default transformations can be added here
      # Any links that point to the /download or /uploads directory should have data-ajax="false"
      @nk.css('a').each do |a_nk|
        if a_nk['href'] =~ /^\/(uploads|download)\//
          a_nk['data-ajax'] = "false"
        end
      end
      
      @html = @nk.to_html
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