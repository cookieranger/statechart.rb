require 'spec_helper'
require 'byebug'

describe '$uniqState' do
  it 'should only return states with unique path' do
    state1, state2, state3 = (1..3).map{ double(path: "./path") }
    uniqStates([state1, state2, state3]).should == [state1]
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
    # covers both cases when you pass in the opts or no opts
    tmp = nil
    state = StateNode.new('a') do |post_state|
      tmp = post_state
    end
    tmp.should == state
  end

  describe 'State#add_substate' do
    before do
      @stateA, @stateB, @stateC = ['a', 'b', 'c'].map{|name| StateNode.new(name)}
      @stateA.add_substate @stateB
      @stateA.add_substate @stateC
    end
    
    it 'should add the given state to the `substates` array' do
      @stateA.substates.should include @stateB, @stateC
    end

    it 'should add the given state to the `substateMap` hash' do
      @stateA.substate_map.should include b: @stateB, c: @stateC
    end

    it 'should set the `superstate` property of the given state' do
      @stateB.superstate.should == @stateA
      @stateC.superstate.should == @stateA
    end

    it 'invokes the `did_attach` method on the substate when its connected to the root statechart' do
      @stateA.should receive(:did_attach)
      StateNode.define.add_substate(@stateA)
    end

    it 'invokes the `did_attach` method on the substate and all of its descendents when a tree of states is connected to the root statechart' do
      [@stateA, @stateB, @stateC].each do |state| 
        state.should receive('did_attach')
      end
      StateNode.define.add_substate(@stateA)
    end

    it 'does NOT invoke the `did_attach` method on the substate when its not connected to the root statechart' do
      [@stateA, @stateB, @stateC].each do |state| 
        state.should_not receive('did_attach')
      end
      StateNode.new('d').add_substate(@stateA)
    end
  end

  describe 'StateNode#is_attached' do
    it 'returns true when the state is connected to a root statechart' do
      # fill in here
    end
  end
end
