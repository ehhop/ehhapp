require 'liquid'
require_relative 'core_ext'

module GitWiki

  module LiquidFilters
    def ago(input)
      (input && input.respond_to?(:to_pretty)) ? input.to_pretty : input
    end
  end
  
end

Liquid::Template.register_filter(GitWiki::LiquidFilters)