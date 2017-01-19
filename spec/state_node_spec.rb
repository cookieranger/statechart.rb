require 'spec_helper'
require 'byebug'

describe StateNode do
  before do
    @state = StateNode.new('a')
  end

  it "should set the name" do
    @state.name.should == 'a'
  end

  it 'should set `substates` property to an empty object' do
    @state.substates.should == []
  end

  it 'should set `current?` to `false`' do
    @state.current?.should == false
  end

  it 'should set `concurrent? to `false`' do
    @state.concurrent?.should == false
  end

  fit 'should create a state_node with `concurrent?` to `true`' do
    @state = StateNode.new(concurrent: true)
    @state.concurrent?.should == true
  end
end
