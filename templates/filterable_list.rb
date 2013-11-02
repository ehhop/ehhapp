module GitWiki

  class FilterableList < TemplateTransformation
    def transform
      @nk.css('ul:first').each do |ul_nk|
        ul_nk['data-role'] = 'listview'
        ul_nk['data-inset'] = 'false'
        ul_nk['data-filter'] = 'true'
        ul_nk['data-filter-placeholder'] = 'My patient needs...'
        ul_nk['data-theme'] = 'd'
      end
      @nk.css('ul:first>li').each do |li_nk|
        li_nk['data-role'] = 'list-divider' if li_nk.css('a').length == 0
      end
      @nk.to_html
    end
  
    example "* List heading", <<-HTML
      <ul data-role="listview" data-inset="false" data-theme="d">
        <li data-role="list-divider">List heading</li>
      </ul>
    HTML
  
    example "* [List item link](destination)", <<-HTML
      <ul data-role="listview" data-inset="false" data-theme="d">
        <li><a href="destination">List item link</a></li>
      </ul>
    HTML
  
  end

end