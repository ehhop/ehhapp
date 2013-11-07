module GitWiki

  class FormularyList < TemplateTransformation
    def transform
      @nk.css('ul:first').each do |ul_nk|
        ul_nk['data-role'] = 'listview'
        ul_nk['data-inset'] = 'false'
        ul_nk['data-filter'] = 'true'
        ul_nk['data-filter-placeholder'] = 'My patient needs...'
        ul_nk['data-theme'] = 'd'
      end
      @nk.css('ul:first>li').each do |li_nk|
        li_nk['data-role'] = 'list-divider' if li_nk.css('strong').length == 0
        li_nk['data-theme'] = 'a' if li_nk.css('h2').length > 0
      end
      @nk.to_html
    end
  
    example "* List heading", <<-HTML
      <ul data-role="listview" data-inset="false" data-theme="d">
        <li data-role="list-divider">List heading</li>
      </ul>
    HTML
  
    example "* # **Drug Name**\n Drug Info (eg price, amount, location)", <<-HTML
      <ul data-role="listview" data-inset="false" data-theme="d">
        <li>Drug Name<br /><span class="drugmeta">Drug Info (eg price, amount, location)</span></li>
      </ul>
    HTML

    example "* ## **BLACKLISTED Drug Name**\n Drug Info (eg price, amount, location)", <<-HTML
      <ul data-role="listview" data-inset="false" data-theme="d">
        <li data-theme="a">BLACKLISTED Drug Name<br /><span class="drugmeta">Drug Info (eg price, amount, location)</span></li>
      </ul>
    HTML

    example "* Putting it together\n* # **Drug Name**\n Drug Info (eg price, amount, location)\n* ## **BLACKLISTED Drug Name**\n Drug Info (eg price, amount, location)", <<-HTML
      <ul data-role="listview" data-inset="false" data-theme="d">
        <li data-role="list-divider">Putting it together</li>
        <li>Drug Name<br /><span class="drugmeta">Drug Info (eg price, amount, location)</span></li>
        <li data-theme="a">BLACKLISTED Drug Name<br /><span class="drugmeta">Drug Info (eg price, amount, location)</span></li>
      </ul>
    HTML
  
  end

end