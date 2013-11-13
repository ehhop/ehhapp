module GitWiki

class DropdownList < TemplateTransformation
  def transform
    nk_html = @nk.to_html

    # convert to dropdown list
    i = 0
    processed = nk_html.to_s.gsub /\+d\s(.*?)(%begin)(.*?)(end%)/m do
      i+=1
      if i == 1
        "<div data-role=\"collapsible-set\"><div data-role=\"collapsible\" data-collapsed=\"true\"><h3><b>#{$1}</b></h3>#{$3}</div>" 
      else
        "<div data-role=\"collapsible\" data-collapsed=\"true\"><h3><b>#{$1}</b></h3>#{$3}</div>"
      end
    end
    processed << "</div>"
    
    junk_num = 0
    # convert -c to checklist
    processed = processed.gsub /((?:^-c.*\n)+)/ do
        c_block = $1
        ret = "<fieldset data-role=\"controlgroup\">"
        matches = c_block.scan(/-c((?:(?!-c).)*)/)
        junk_num = 0
        matches.each do |item|
          junk_num+=1
          ret << "<input type=\"checkbox\" name=\"checkbox-#{junk_num}\" id=\"checkbox-#{junk_num}\" class=\"custom\" data-mini=\"true\"/><label for=\"checkbox-#{junk_num}\">#{item[0]}</label>"
        end
        ret << "</fieldset>"
        ret
    end
    
    # convert -r to radio button

    processed
  end

  example "* Dropdown Heading %begin -put stuff here- end%", <<-HTML
      <div data-role="collapsible" data-collapsed="true"><h3><b>Dropdown Heading</b></h3></div>
  HTML
  
  example "-c Checklist Item", <<-HTML
      <fieldset data-role="controlgroup">
	    <input type="checkbox" name="checkbox-1a" id="checkbox-1a" class="custom" data-mini="true" />
        <label for="checkbox-1a">Checklist Item</label>
      </fieldset>
  HTML
 
end

end
