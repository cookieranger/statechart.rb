require 'spec_helper'

describe "Working" do
  it 'has a version number' do
    Statechart::VERSION.should_not == nil
  end

  it 'does something useful' do
    false.should == false
  end
end
