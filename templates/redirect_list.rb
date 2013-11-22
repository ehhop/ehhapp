module GitWiki

class RedirectList < TemplateTransformation
  def transform
    @nk.css('ul:first').each do |ul_nk|
        ul_nk['data-role'] = 'listview'
        ul_nk['data-inset'] = 'true'
        ul_nk['data-filter'] = 'true'
        ul_nk['data-filter-placeholder'] = 'Filter items...'
    end
    @nk.to_html
  end

  example "* [This is a link](/target)\n* [This is link 2](/target)\n* [This is link 3](/target)", <<-HTML
      <ul data-role="listview" data-inset="true" data-filter="true">
	    <li><a href="/target">This is a link</a></li>
	    <li><a href="/target">This is link 2</a></li>
	    <li><a href="/target">This is link 3</a></li>
      </ul>		
  HTML
 
end
end
