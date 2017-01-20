require 'spec_helper'
require 'byebug'

describe '$uniqState' do
  it 'should only return states with unique path' do
    state1 = double(path: './path1')
    state2 = double(path: './path2')
    state3 = double(path: './path1')
    uniqStates([state1, state2, state3]).should == [state1, state2]
  end
end

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

  it 'should create a state_node with `concurrent?` to `true`' do
    @state = StateNode.new('a', concurrent: true)
    @state.concurrent?.should == true
  end
end
