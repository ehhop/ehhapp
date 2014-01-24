module GitWiki

class CollapsibleList < TemplateTransformation
  def transform

    collapsible_set = Nokogiri::HTML.fragment('<div data-role="collapsible-set" />').at_css('div')
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
        collapsible = Nokogiri::HTML.fragment('<div data-role="collapsible" data-collapsed="true"><h3 /></div>').at_css('div')
        collapsible.at_css('h3').content = curr_element.content
        curr_collapsible = collapsible_set.add_child(collapsible)
      elsif curr_element.name == 'h4' && curr_collapsible
        # Allow nesting of collapsibles with h4's!
        collapsible = Nokogiri::HTML.fragment('<div data-role="collapsible" data-collapsed="true"><h4 /></div>').at_css('div')
        collapsible.at_css('h4').content = curr_element.content
        curr_collapsible = curr_collapsible.add_child(collapsible)
      elsif curr_element.name == 'blockquote'
        fieldset = Nokogiri::HTML.fragment('<fieldset data-role="controlgroup" />').at_css('fieldset')
        curr_element.css('li').each do |li_nk|
          checkbox = Nokogiri::HTML.fragment('<input type="checkbox" class="custom" data-mini="true"/>').at_css('input')
          checkbox['name'] = "#{@page.name}-checkbox-#{tmp_index}"
          checkbox['id'] = "#{@page.name}-checkbox-#{tmp_index}"
          label = Nokogiri::HTML.fragment("<label />").at_css('label')
          label['for'] = "#{@page.name}-checkbox-#{tmp_index}"
          label.content = li_nk.content
          fieldset.add_child(checkbox)                
          fieldset.add_child(label)
          tmp_index += 1
        end
        curr_collapsible.add_child(fieldset)
        # Break out of a nested collapsible, if we are nested
        curr_collapsible = curr_collapsible.parent if curr_collapsible.parent['data-role'] == 'collapsible'
      else
        curr_collapsible.add_child(curr_element)
      end
      curr_element = next_element
    end
    @nk.to_html
  end

  md_example = <<-MD
This template turns headers into tappable
buttons that open new content within.

### This header is collapsible.

This paragraph will collapse "inside"
the above header.
  MD

  example md_example, <<-HTML
    <p>This template turns headers into tappable
buttons that open new content within.</p>
    <div data-role="collapsible" data-collapsed="true">
      <h3><b>This header is collapsible.</b></h3>
      <fieldset data-role="controlgroup">
        <p>This paragraph will collapse "inside" the above header.</p>
      </fieldset>
    </div>
  HTML
  
  md_example = <<-MD
You can have other content before
all the collapsibles.

### You can make several of them.

Content in the first one.

### Here's another.

Content in the second one.
  MD

  example md_example, <<-HTML
    <p>You can have other content before all the collapsibles.</p>
    <div data-role="collapsible-set">
      <div data-role="collapsible" data-collapsed="true">
        <h3><b>You can make several of them.</b></h3>
        <fieldset data-role="controlgroup">
          <p>Content in the first one.</p>
        </fieldset>
      </div>
      <div data-role="collapsible" data-collapsed="true">
        <h3><b>Here's another.</b></h3>
        <fieldset data-role="controlgroup">
          <p>Content in the second one.</p>
        </fieldset>
      </div>
    </div>
  HTML

  md_example = <<-MD
### This header is collapsible.

You can also have checklists like this:

>+ checkbox 1 starts like this.
>+ checkbox 2 is similar,
>  and you can span multiple lines...
>+ checkbox 3.
  MD

  example md_example, <<-HTML
    <div data-role="collapsible" data-collapsed="true">
      <h3><b>This header is collapsible.</b></h3>
      <fieldset data-role="controlgroup">
        <p>You can also have checklists like this:</p>
        <input type="checkbox" name="checkbox-ex-1" id="checkbox-ex-1" class="custom" data-mini="true" />
        <label for="checkbox-ex-1">checkbox 1 starts like this.</label>
        <input type="checkbox" name="checkbox-ex-2" id="checkbox-ex-2" class="custom" data-mini="true" />
        <label for="checkbox-ex-2">checkbox 2 is similar, and you can span multiple lines...</label>
        <input type="checkbox" name="checkbox-ex-3" id="checkbox-ex-3" class="custom" data-mini="true" />
        <label for="checkbox-ex-3">checkbox 3.</label>
      </fieldset>
    </div>
  HTML
 
  md_example = <<-MD
Finally, you can *nest* collapsible items
for special cases.

### Outer collapsible

>+ Please place an order for the referral in EPIC. 

The following steps depend on special conditions.

#### Patient is over 65

>+ Special order 1
>+ Special order 2

#### Patient has kidney disease

>+ Special order 3
>+ Special order 4

### And this one is not nested.

Content under the second header.
  MD
  
  example md_example, <<-HTML
  <p>Finally, you can <em>nest</em> collapsible items
  for special cases.</p>

  <div data-role="collapsible-set">
    <div data-role="collapsible" data-collapsed="true">
      <h3>Outer collapsible</h3>
      <fieldset data-role="controlgroup">
        <input type="checkbox" class="custom" data-mini="true" name="somewhur-checkbox-1" id="somewhur-checkbox-1"><label for="somewhur-checkbox-1">Please place an order for the referral in EPIC.</label>
      </fieldset>
      <p>The following steps depend on special conditions.</p>
      <div data-role="collapsible" data-collapsed="true">
        <h4>Patient is over 65</h4>
        <fieldset data-role="controlgroup">
          <input type="checkbox" class="custom" data-mini="true" name="somewhur-checkbox-2" id="somewhur-checkbox-2"><label for="somewhur-checkbox-2">Special order 1</label><input type="checkbox" class="custom" data-mini="true" name="somewhur-checkbox-3" id="somewhur-checkbox-3"><label for="somewhur-checkbox-3">Special order 2</label>
        </fieldset>
      </div>
      <div data-role="collapsible" data-collapsed="true">
        <h4>Patient has kidney disease</h4>
        <fieldset data-role="controlgroup">
          <input type="checkbox" class="custom" data-mini="true" name="somewhur-checkbox-4" id="somewhur-checkbox-4"><label for="somewhur-checkbox-4">Special order 3</label><input type="checkbox" class="custom" data-mini="true" name="somewhur-checkbox-5" id="somewhur-checkbox-5"><label for="somewhur-checkbox-5">Special order 4</label>
        </fieldset>
      </div>
    </div>
    <div data-role="collapsible" data-collapsed="true">
      <h3>And this one is not nested.</h3>
      <p>Content under the second header.</p>
    </div>
  </div>
  HTML
  
end

end
