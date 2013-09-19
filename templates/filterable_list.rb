module GitWiki

class FilterableList < TemplateTransformation
  def transform
    @nk.css('ul:first').each do |ul_nk|
      ul_nk['data-role'] = 'listview'
      ul_nk['data-inset'] = 'false'
      ul_nk['data-filter'] = 'true'
      ul_nk['data-filter-placeholder'] = 'My patient needs...'
      ul_nk['data-theme'] = 'd'
    end
    @nk.css('ul:first>li').each do |li_nk|
      li_nk['data-role'] = 'list-divider' if li_nk.css('a').length == 0
    end
    @nk.to_html
  end
end

end