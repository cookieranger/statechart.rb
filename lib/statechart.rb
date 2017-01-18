require "statechart/version"

class Statechart
  include Version
  attr_accessor :name
  
  def initialize(name)
    @name = name
  end
end
