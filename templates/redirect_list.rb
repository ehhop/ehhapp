module GitWiki

class RedirectList < TemplateTransformation
  def transform
    # set placeholder
    placeholder = 'Filter items...'
    tmp_pt = @nk.at_css('*')
    if tmp_pt.name == 'p'
      placeholder = tmp_pt.content
      tmp_pt.unlink
    end

    @nk.css('ul:first').each do |ul_nk|
      ul_nk['class'] = 'redirect-list'
      ul_nk['data-role'] = 'listview'
      ul_nk['data-inset'] = 'true'
      ul_nk['data-filter'] = 'true'
      ul_nk['data-filter-placeholder'] = placeholder
      ul_nk.css('li').each do |li_nk|
        a_nk = li_nk.css('a:first').first
        if a_nk && a_nk['href'] =~ /^tel:/
          li_nk['data-icon'] = 'phone'
        end
        if a_nk && (parts = a_nk.content.split('|', 2))
          span_nk = Nokogiri::XML::Node.new "span", @nk
          span_nk.content = parts[1]
          span_nk["class"] = "secondary"
          a_nk.content = parts[0]
          a_nk.add_child(Nokogiri::XML::Node.new "br", @nk)
          a_nk.add_child(span_nk)
        end
      end
    end
    custom_styled = @nk.to_html
  end

  example "The first line specifies the placeholder in the search bar.\n\nIf you also want text at the top,\nbe sure to put two returns between the first line\nand the text, and the list and the text.\n\n* [This is a link](/target)\n* [This is link 2](/target)\n* [This is link 3](/target)", <<-HTML
      <p>If you also want text at the top, be sure to put two returns between the first line and the text, and the list and the text.</p>
      <ul data-role="listview" data-inset="true" data-filter="true" data-filter="true" data-filter-placeholder="The first line specifies the placeholder in the search bar.">
	    <li><a href="/target">This is a link</a></li>
	    <li><a href="/target">This is link 2</a></li>
	    <li><a href="/target">This is link 3</a></li>
      </ul>		
  HTML
 
end
end
