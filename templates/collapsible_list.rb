module GitWiki

class CollapsibleList < TemplateTransformation
  def transform

    collapsible_set = Nokogiri::HTML.parse("<div data-role=\"collapsible-set\"></div>").at_css('div')
    start_point = @nk.at_css('h3')
    start_point.add_previous_sibling(collapsible_set)
    collapsible_set = @nk.at_css('div[data-role=collapsible-set]')
    tmp_index = 1
    curr_element = start_point
    curr_collapsible = nil
    
    while true
        break unless curr_element
        next_element = curr_element.next_element
        curr_element.unlink
        if curr_element.name == 'h3'
            collapsible = Nokogiri::HTML.parse("<div data-role=\"collapsible\" data-collapsed=\"true\"><h3><b>#{curr_element.content}</b></h3></div>").at_css('div')
            curr_collapsible = collapsible_set.add_child(collapsible)
        elsif curr_element.name == 'blockquote'
            fieldset = Nokogiri::HTML.parse("<fieldset data-role=\"controlgroup\"></fieldset>")
            curr_element.css('li').each do |li_nk|
                checkbox = Nokogiri::HTML.parse("<input type=\"checkbox\" name=\"checkbox-#{tmp_index}\" id=\"checkbox-#{tmp_index}\" class=\"custom\" data-mini=\"true\"/>")
                label = Nokogiri::HTML.parse("<label for=\"checkbox-#{tmp_index}\">#{li_nk.content}</label>")
                tmp_index += 1
                fieldset.at_css('fieldset').add_child(checkbox.at_css('input'))                
                fieldset.at_css('fieldset').add_child(label.at_css('label'))
            end
            curr_collapsible.add_child(fieldset.at_css('fieldset'))
        else
            curr_collapsible.add_child(curr_element)
        end
        curr_element = next_element
    end
    @nk.to_html
  end

  example "### Dropdown Header\n>+ option1\n> continuation\n>+ option2\n>+ option3\n> yet another continuation", <<-HTML
      <div data-role="collapsible" data-collapsed="true"><h3><b>Dropdown Header</b></h3><fieldset data-role="controlgroup">
	  <input type="checkbox" name="checkbox-2" id="checkbox-2" class="custom" data-mini="true" />
      <label for="checkbox-2">option1 continuation</label>
      <input type="checkbox" name="checkbox-2a" id="checkbox-2a" class="custom" data-mini="true" />
      <label for="checkbox-2a">option2</label>
 	  <input type="checkbox" name="checkbox-1" id="checkbox-1" class="custom" data-mini="true" />
      <label for="checkbox-1">option3 yet another continuation</label>
</fieldset></div>
  HTML
  
 
end

end
