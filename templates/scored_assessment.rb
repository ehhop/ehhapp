module GitWiki

class ScoredAssessment < TemplateTransformation
  def transform
    ol_nk = @nk.at_css('ol:first')
    new_form = Nokogiri::HTML.fragment('<form/>').at_css('form')
    ol_nk.add_next_sibling(new_form)
    new_div = Nokogiri::HTML.fragment('<div data-role="fieldcontain"/>').at_css('div')
    new_form.add_child(new_div)
    id_count = 1
    q_count = 1
    
    @nk.css('ol:first > li').each do |li_nk|
      new_fieldset = Nokogiri::HTML.fragment('<fieldset data-role="controlgroup" data-mini="true"/>').at_css('fieldset')
      new_div.add_child(new_fieldset)
      new_legend = Nokogiri::HTML.fragment('<legend />').at_css('legend')
      new_legend.content = "#{q_count}. #{li_nk.children.first.content}"
      new_fieldset.add_child(new_legend)
      new_fieldset.add_child(li_nk.at_css('ul'))
      
      value = 0
      new_fieldset.css('ul > li').each do |ul_li_nk|
        choice = ul_li_nk.content
        ul_li_nk.children = ''
        
        new_input = Nokogiri::HTML.fragment('<input type="radio"/>').at_css('input')
        id = new_input['id'] = "#{@page.name}-rdo-#{id_count}"
        new_input['name'] = "#{@page.name}_#{q_count}"
        new_input['value'] = value
        ul_li_nk.add_child(new_input)
        
        new_label = Nokogiri::HTML.fragment('<label/>').at_css('label')
        new_label['for'] = id
        new_label.content = choice
        ul_li_nk.add_child(new_label)
        
        value += 1
        id_count += 1
      end
      q_count += 1
    end
    ol_nk.unlink
    
    @nk.to_html
  end
  
  md = <<-MD
Initial prompt at the top

1. First multiple choice question
    - Each choice
    - goes in a nested list
    - like this
MD

  example md, <<-HTML
  <p>Initial prompt at the top</p>

  <form><div data-role="fieldcontain"><fieldset data-role="controlgroup" data-mini="true">
  <legend>1. First multiple choice question</legend>
  <ul>
  <li>
  <input type="radio" id="GAD7-rdo-1" name="GAD7_1" value="0"><label for="GAD7-rdo-1">Each choice</label>
  </li>
  <li>
  <input type="radio" id="GAD7-rdo-2" name="GAD7_1" value="1"><label for="GAD7-rdo-2">goes in a nested list</label>
  </li>
  <li>
  <input type="radio" id="GAD7-rdo-3" name="GAD7_1" value="2"><label for="GAD7-rdo-3">like this</label>
  </li>
  </ul>
  </fieldset></div></form>
  HTML
  
end

end