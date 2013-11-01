module GitWiki

class Unstyled < TemplateTransformation
  def transform
    @nk.to_html
  end
end

end