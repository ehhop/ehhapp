module Grit
  class Blob
    attr_writer :name
  end
end

class BlobAlike
    attr_accessor :name
    attr_accessor :data
    attr_accessor :id
    
    def initialize(name, data)
      @name = name
      @data = data
      @id = nil
    end
end
