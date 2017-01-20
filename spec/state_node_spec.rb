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

  it 'should be able to create a StateNode with `concurrent?` to `true`' do
    StateNode.new('a', concurrent: true).concurrent?.should == true
  end

  # history
  it 'should default `history` to `false`' do
    @state.history?.should == false
  end

  it 'should be able to create a StateNode with `history` to `true` via `H` option' do
    state = StateNode.new('a', H: true)
    state.history?.should == true
    state.deep?.should == false
  end

  it 'should be able to create a StateNode with `history` and `deep` to `true` via setting `H` option to `*`' do
    state = StateNode.new('a', H: '*')
    state.history?.should == true
    state.deep?.should == true
  end

  it 'should Raise Excpetion if `concurrent` and `H` are both set' do
    -> { StateNode.new('a', H: true, concurrent: true) }.should raise_error StateNode::ConcurrentHistoryError
  end

  it 'should invoke the given function with the the newly constructed StateNode' do
    tmp = nil
    state = StateNode.new('a') do |post_state|
      tmp = post_state
    end
    tmp.should == state
  end
end
