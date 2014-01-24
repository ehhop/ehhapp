module GitWiki

  class FilterableList < TemplateTransformation
    def transform
      # set placeholder
      placeholder = 'My patient needs...'
      tmp_pt = @nk.at_css('*')
      if tmp_pt.name == 'p'
        placeholder = tmp_pt.content
        tmp_pt.unlink
      end

      @nk.css('ul:first').each do |ul_nk|
        ul_nk['data-role'] = 'listview'
        ul_nk['data-inset'] = 'false'
        ul_nk['data-filter'] = 'true'
        ul_nk['data-filter-placeholder'] = placeholder
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
  
    example "* [List item link](URL)", <<-HTML
      <ul data-role="listview" data-inset="false" data-theme="d">
        <li><a href="URL">List item link</a></li>
      </ul>
    HTML
    
    md_example = <<-MD
The first line specifies the placeholder in the search bar.

It is optional, but if you want text at the top,
be sure to put two breaks between the first line
and the text, and the list and the text.

* Putting it together
* [First link](dest_1)
* [Next link](dest_2)
    MD
    
    example md_example, <<-HTML
      <p>It is optional, but if you want text at the top, be sure to put 
        two breaks between the first line and the text, and the list and the text.</p>
      <ul data-role="listview" data-inset="false" data-theme="d" data-filter="true" 
        data-filter-placeholder="The first line specifies the placeholder in the search and is optional.">
        <li data-role="list-divider">Putting it together</li>
        <li><a href="dest_1">First link</a></li>
        <li><a href="dest_2">Next link</a></li>
      </ul>
    HTML
  
  end

end
