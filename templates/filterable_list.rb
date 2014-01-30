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
      
      tag_next_li = nil
      @nk.css('ul:first>li').each do |li_nk|
        a_nk = li_nk.css('a:first').first
        if !a_nk
          li_nk['data-role'] = 'list-divider'   # This is a header within the list
          li_nk.content = li_nk.content         # Strip all elements within
          tag_next_li = li_nk.content           # Tag following items with it
        else
          if li_nk.css('p').length >= 1
            # Strip out paragraphs that might have crept into list items
            li_nk.children = li_nk.at_css('p:first').children
          end
          parts = a_nk.content.split('|', 2)
          # Add hidden tags to the item
          if parts && parts.length > 1 && parts[1].strip.length > 0
            span_nk = Nokogiri::XML::Node.new "span", @nk
            span_nk.content = parts[1].strip
            span_nk["class"] = "category"
            a_nk.content = parts[0]
            a_nk.add_child(span_nk)
          end
          if tag_next_li
            span_nk = Nokogiri::XML::Node.new "span", @nk
            span_nk.content = tag_next_li
            span_nk["class"] = "category"
            li_nk.add_child(span_nk)
          end
        end
      end
      @nk.to_html
    end
  
    example "* ### List heading", <<-HTML
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

You can also separate sections within the list
with a blank line.

* ### Putting it together
* [First link](dest_1)
* [Next link](dest_2)

* ### Next section
* [Third link](dest_3)
    MD
    
    example md_example, <<-HTML
      <p>It is optional, but if you want text at the top, be sure to put 
        two breaks between the first line and the text, and the list and the text.</p>
      <p>You can also separate sections within the list with a blank line.</p>
      <ul data-role="listview" data-inset="false" data-theme="d" data-filter="true" 
        data-filter-placeholder="The first line specifies the placeholder in the search and is optional.">
        <li data-role="list-divider">Putting it together</li>
        <li><a href="dest_1">First link</a></li>
        <li><a href="dest_2">Next link</a></li>
        <li data-role="list-divider">Next section</li>
        <li><a href="dest_3">Third link</a></li>
      </ul>
    HTML
    
    md_example = <<-MD
Try searching for "secret tag".

You can add extra tags that can be searched for after a pipe character.

* [Different link](dest_1)
* [You'll find me! | secret tag](URL)
MD
    
    example md_example, <<-HTML
      <p>You can add extra tags that can be searched for after a pipe character.</p>
      <ul data-role="listview" data-inset="false" data-theme="d" data-filter="true"
        data-filter-placeholder="Try searching for &quot;secret tag&quot;.">
        <li><a href="dest_1">Different link</a></li>
        <li><a href="URL">You'll find me!</a><span class="category">secret tag</span></li>
      </ul>
    HTML
  
  end

end
