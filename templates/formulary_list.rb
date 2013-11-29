module GitWiki

  class FormularyList < TemplateTransformation
    def transform
      # set placeholder
      placeholder = 'My patient needs...'
      tmp_pt = @nk.at_css('*')
      if tmp_pt.name == 'p'
        placeholder = tmp_pt.content
        tmp_pt.unlink
      end

      # add search bar
      @nk.css('ul:first').each do |ul_nk|
        ul_nk['data-role'] = 'listview'
        ul_nk['data-inset'] = 'false'
        ul_nk['data-filter'] = 'true'
        ul_nk['data-filter-placeholder'] = placeholder
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
          split_res = next_sib.content.split("\n")
          split_res.each do |item|
            new_res = item.split('|')
            next unless new_res.length > 0
            if new_res[0].match(/\s*~(.*)/)
              new_node = Nokogiri::HTML.fragment('<li data-theme="a" />').at_css('li')
              new_node.content = $1
            else
              new_node = Nokogiri::HTML.fragment("<li />").at_css('li')
              new_node.content = new_res[0]
            end
            if new_res.length >= 2
              drugmeta = '<br /><span class="drugmeta"><span class="prices"/><span class="category"/></span>'
              drugmeta_nk = Nokogiri::HTML.fragment(drugmeta)
              new_node.add_child(drugmeta_nk)
              new_node.at_css('.prices').content = new_res[1]
              new_node.at_css('.category').content = category
              if new_res.length >= 3
                subcat_nk = Nokogiri::HTML.fragment('<span class="subcategory" />').at_css('span')
                subcat_nk.content = new_res[2]
                new_node.at_css('.drugmeta').add_child(subcat_nk)
              end
            end
            next_sib.add_previous_sibling(new_node)
          end
          next_sib.unlink
        end     
      end
      @nk.to_html
    end
  
    md_example = <<-MD
* Drug Type
> Drug Name | $1.23 (200mg) | tag1 tag2 tag3
> ~Banned Drug | $1.23 (200mg) | tag2 tag3 tag4
    MD

    example md_example, <<-HTML
      <ul data-role="listview" data-inset="false" data-theme="d">
        <li data-role="list-divider">Drug Type</li>
        <li>Drug Name<br />
          <span class="drugmeta">
            <span class="prices">$1.23 (200mg)</span>
            <span class="category">Other</span>
            <span class="subcategory">tag1 tag2 tag3</span>
          </span>
        </li>
        <li data-theme="a">Banned Drug<br />
          <span class="drugmeta">
            <span class="prices">$1.23 (200mg)</span>
            <span class="category">Other</span>
            <span class="subcategory">tag2 tag3 tag4</span>
          </span>
        </li>
      </ul>
    HTML
  
  end

end
