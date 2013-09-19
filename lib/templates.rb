require "nokogiri"

module GitWiki

  class TemplateTransformation
    def initialize(html)
      @html = html
      @nk = Nokogiri::HTML.fragment(html, "UTF-8")
    end
  
    def transform; @html; end
  end

  require_all "templates/*.rb"

end