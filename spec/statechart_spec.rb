require 'spec_helper'
require 'byebug'

describe Statechart do
  before do
    @chart = Statechart.new('a')
  end

  it "should set the name" do
    @chart.name.should == 'a'
  end
end
