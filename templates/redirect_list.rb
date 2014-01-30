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
      
      tag_next_li = nil
      ul_nk.css('li').each do |li_nk|
        a_nk = li_nk.css('a:first').first
        if a_nk
          li_nk['data-icon'] = 'phone' if a_nk['href'] =~ /^tel:/
          if li_nk.css('p').length >= 1
            # Strip out paragraphs that might have crept into list items
            li_nk.children = li_nk.at_css('p:first').children
          end
          parts = a_nk.content.split('|', 3)
          # Add second line to the item
          if parts.length > 1
            a_nk.content = parts[0]
            if parts[1].strip.length > 0
              span_nk = Nokogiri::XML::Node.new "span", @nk
              span_nk.content = parts[1].strip
              span_nk["class"] = "secondary"
              a_nk.add_child(Nokogiri::XML::Node.new("br", @nk))
              a_nk.add_child(span_nk)
            end
          end
          # Add hidden tags to the item
          if parts.length > 2 && parts[2].strip.length > 0
            span_nk = Nokogiri::XML::Node.new "span", @nk
            span_nk.content = parts[2].strip
            span_nk["class"] = "category"
            a_nk.add_child(span_nk)
          end
          if tag_next_li
            span_nk = Nokogiri::XML::Node.new "span", @nk
            span_nk.content = tag_next_li
            span_nk["class"] = "category"
            a_nk.add_child(span_nk)
          end
        else
          li_nk['data-role'] = 'list-divider'  # This is a header within the list
          li_nk.content = li_nk.content        # Strip all elements within
          tag_next_li = li_nk.content
        end
      end
    end
    custom_styled = @nk.to_html
  end
  
  md = <<-MD
Text at the top becomes the search prompt.

* [This is a link](/target)
MD

  example md, <<-HTML
      <ul data-role="listview" data-inset="true" data-filter="true" class="redirect-list"
        data-filter-placeholder="Text at the top becomes the search prompt.">
        <li><a href="/target">This is a link</a></li>
      </ul> 	
  HTML

  md = <<-MD
* [This link places a call | 
    to 877-372-4161](tel:+18773724161)
MD

  example md, <<-HTML
      <ul data-role="listview" data-inset="true" class="redirect-list">
        <li data-icon="phone"><a href="tel:+18773724161">This link places a call<br/>
          <span class="secondary">to 877-372-4161</span></a></li>
      </ul> 	
  HTML
  
  md = <<-MD
* ### This becomes a header.
MD

  example md, <<-HTML
      <ul data-role="listview" data-inset="true" class="redirect-list">
        <li data-role="list-divider">This becomes a header.</li>
      </ul> 	
  HTML
  
  md = <<-MD
Putting it all together.

* [This is a link](/target)

* ### Blank lines are allowed.
* [This is a link | 
    with secondary text](/target2)
* [This link places a call | 
    to 877-372-4161](tel:+18773724161)
MD

  example md, <<-HTML
      <ul data-role="listview" data-inset="true" data-filter="true" class="redirect-list"
        data-filter-placeholder="Putting it all together.">
        <li><a href="/target">This is a link</a></li>
        <li data-role="list-divider">Blank lines are allowed.</li>
        <li><a href="/target2">This is a link<br/><span class="secondary">with secondary text</span></a></li>
        <li data-icon="phone"><a href="tel:+18773724161">This link places a call<br/>
          <span class="secondary">to 877-372-4161</span></a></li>
      </ul> 	
  HTML
  
    md_example = <<-MD
Try searching for "secret tag".

You can add extra tags that can be searched for after a second pipe character.

* [Different link](dest_1)
* [You'll find me! | | secret tag](URL)
MD
    
    example md_example, <<-HTML
      <p>You can add extra tags that can be searched for after a pipe character.</p>
      <ul data-role="listview" data-inset="true" data-filter="true" class="redirect-list"
        data-filter-placeholder="Try searching for &quot;secret tag&quot;.">
        <li><a href="dest_1">Different link</a></li>
        <li><a href="URL">You'll find me!</a><span class="category">secret tag</span></li>
      </ul>
    HTML
 
end
end
