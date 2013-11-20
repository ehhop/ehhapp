module GitWiki

  class FormularyList < TemplateTransformation
    def transform
      puts @nk.to_html
      puts 'FIGARO'
      # add search bar
      @nk.css('ul:first').each do |ul_nk|
        ul_nk['data-role'] = 'listview'
        ul_nk['data-inset'] = 'false'
        ul_nk['data-filter'] = 'true'
        ul_nk['data-filter-placeholder'] = 'My patient needs...'
        ul_nk['data-theme'] = 'd'
      end
      # form header
      @nk.css('ul li').each do |li_nk|
        li_nk['data-role'] = 'list-divider'
        li_nk['data-theme'] = 'a'
      end
      # convert all blockquotes to li and move it out
      @nk.css('li blockquote').each do |bq_nk|
        bq_nk.name = 'li' 
        bq_nk.parent.add_next_sibling(bq_nk)
      end
      # trash p tags
      @nk.css('p').each do |p_nk|
        p_nk.parent.add_child(p_nk.content)
        p_nk.unlink
      end
      # parse drugs
      @nk.css('li[data-role=list-divider]').each do |li_nk|
        category = li_nk.content
        if li_nk.next_sibling and !li_nk.next_sibling.get_attribute('data-role')
            next_sib = li_nk.next_sibling
            next_sib.content.gsub /^([^\|]*)\|([^\|]*)\|([^\|]*)$/ do
              name = $1
              price = $2
              tags = $3
              if $1.match(/\s*~(.*)/)
                name = $1
                new_node = Nokogiri::HTML.parse("<li data-theme = \"a\">#{name}<br /><span class=\"drugmeta\"><span class=\"prices\">#{price}</span><span class=\"category\">#{category}</span><span class=\"subcategory\">#{tags}</span></span></li>").css('li')
              else
                new_node = Nokogiri::HTML.parse("<li>#{name}<br /><span class=\"drugmeta\"><span class=\"prices\">#{price}</span><span class=\"category\">#{category}</span><span class=\"subcategory\">#{tags}</span></span></li>").css('li')
              end
              next_sib.add_previous_sibling(new_node)
            end
            next_sib.unlink
        end     
      end
      @nk.to_html
    end
  

    example "* Drug Type\n> Drug Name | $1.23 (200mg) | tag1 tag2 tag3\n> ~Banned Drug | $1.23 (200mg) | tag2 tag3 tag4", <<-HTML
      <ul data-role="listview" data-inset="false" data-theme="d">
        <li data-role="list-divider">Drug Type</li>
        <li>Drug Name<br /><span class=\"drugmeta\"><span class=\"prices\">$1.23 (200mg)</span><span class=\"category\">Other</span><span class=\"subcategory\">tag1 tag2 tag3</span></span></li>
        <li data-theme = \"a\">Banned Drug<br /><span class=\"drugmeta\"><span class=\"prices\">$1.23 (200mg)</span><span class=\"category\">Other</span><span class=\"subcategory\">tag2 tag3 tag4</span></span></li>
      </ul>
    HTML
  
  end

end
