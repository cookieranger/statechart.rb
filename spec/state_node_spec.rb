require 'spec_helper'
require 'byebug'

describe '$uniq_states' do
  it 'should only return states with unique path' do
    state1, state2, state3 = (1..3).map{ double(path: "./path") }
    uniq_states([state1, state2, state3]).should == [state1]
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

  describe '#add_substate dependencies' do
    before do
      @stateA, @stateB, @stateC = ['a', 'b', 'c'].map{|name| StateNode.new(name)}
      @stateA.add_substate @stateB
      @stateA.add_substate @stateC
    end

    describe 'State#add_substate' do
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
        StateNode.define.add_substate(@stateA)
        [@stateA, @stateB, @stateC].each do |state| 
          state.attached?.should == true
        end
      end

      it 'returns false when the state is NOT connected to a root statechart' do
        StateNode.new('d').add_substate(@stateA)
        [@stateA, @stateB, @stateC].each do |state| 
          state.attached?.should == false
        end
      end
    end

    describe 'StateNode#for_each_descendant_states' do
      it 'should yield each state in the receivers hierarchy' do
        collector = []
        StateNode.new('d').add_substate(@stateA)
          .for_each_descendant_states do |state|
            collector << state.name
          end
        collector.should include('d', 'a', 'b', 'c')
      end
    end

    describe 'StateNode#root' do
      it 'should return the root of the tree' do
        stateD = StateNode.new('d').add_substate(@stateA)
        stateD.root.should == stateD
        @stateA.root.should == stateD
        @stateB.root.should == stateD
        @stateC.root.should == stateD
      end
    end

    describe 'StateNode#path' do
      it 'should return a string of "/" separated state names leading up the root state' do
        p @stateA.superstate
        @stateA.path.should == '/'
        @stateB.path.should == '/b'
        @stateC.path.should == '/c'

        stateD = StateNode.new('d')
        @stateC.add_substate stateD
        stateD.path.should == '/c/d'
      end
    end
  end

  describe '#goto dependencies' do
    describe 'StateNode#all_active_paths <<- State#current' do
      let(:root) { StateNode.define }
      let(:state_concurrent) { StateNode.new('concurrent', { concurrent: true }) }
      let(:state1) { StateNode.new('1') }
      let(:state2) { StateNode.new('2') }
      let(:state3) { StateNode.new('3') }
      let(:stateA) { StateNode.new('a') }
      let(:stateB) { StateNode.new('b') }
      let(:stateC) { StateNode.new('c') }
      
      before do 
        state1.add_substate(state2).add_substate(state3)
        stateA.add_substate(stateB).add_substate(stateC)

        state_concurrent.add_substate(state1).add_substate(stateA)
        root.add_substate(state_concurrent)
        root.goto
      end

      it 'initially should have two active states' do
        state_concurrent.all_active_paths.should =~ ['/concurrent/a/b', '/concurrent/1/2'] # viva rspec lazy people
      end

      it 'should return an empty array when state is not current' do
        stateB.__is_current__?.should == true
        state2.__is_current__?.should == true

        stateC.__is_current__?.should == false
        state3.__is_current__?.should == false
      end

      it 'should return an array of all current leaf state paths' do
        root.goto('/concurrent/a/b', '/concurrent/1/3')
        state_concurrent.all_active_paths.should =~ ['/concurrent/a/b', '/concurrent/1/3']
      end
    end

    # direct translated replica of statechart.js
    describe 'StateNode#goto' do
      let(:root) { StateNode.new('root')                  }
      let(:a)    { StateNode.new('a')                     }
      let(:b)    { StateNode.new('b', {H: true})          }
      let(:c)    { StateNode.new('c')                     }
      let(:d)    { StateNode.new('d')                     }
      let(:e)    { StateNode.new('e', {H: '*'})           }
      let(:f)    { StateNode.new('f')                     }
      let(:g)    { StateNode.new('g', {concurrent: true}) }
      let(:h)    { StateNode.new('h')                     }
      let(:i)    { StateNode.new('i')                     }
      let(:j)    { StateNode.new('j')                     }
      let(:k)    { StateNode.new('k')                     }
      let(:l)    { StateNode.new('l')                     }
      let(:m)    { StateNode.new('m')                     }

      before do
        root.add_substate(a);
        a.add_substate(b);
        a.add_substate(e);
        b.add_substate(c);
        b.add_substate(d);
        e.add_substate(f);
        e.add_substate(g);
        g.add_substate(h);
        g.add_substate(k);
        h.add_substate(i);
        h.add_substate(j);
        k.add_substate(l);
        k.add_substate(m);

        root.goto
        states = [root, a, b, c, d, e, f, g, h, i, j, k, l, m];

        # configure enter and exit 
        enters, exits = [], []
        states.each do |state|
          state.upon_enter { |s| enters << s }
          state.upon_exit { |s| enters << s }
        end
      end

      describe 'on the root state' do
        it 'should transition to all default states when no paths are given' do
          root.all_active_paths.should == ['/a/b/c']
        end

        it 'should transition all current states to the given states' do
          root.goto('/a/e/g/h/j', '/a/e/g/k/l')
          root.all_active_paths.should == ['/a/e/g/h/j', '/a/e/g/k/l']
          root.goto('/a/b/d')
          root.all_active_paths.should == ['/a/b/d']
        end
      end

      it 'should throw an exception when the receiver state is NOT current' do
        -> { d.goto('/a/e/f') }.should raise_error StateNode::InactiveStateError
      end

      it 'should throw an exception when multiple pivot states are found betweeen receiver and the given destination paths' do
        -> { c.goto('/a/b/d', '/a/e/f') }.should raise_error StateNode::MultiplePivotError
      end

      it 'should throw an exception if any given destination state is NOT reachable from the receiver' do
        root.goto('/a/e/g/h/i')
        -> { i.goto('/a/e/g/k/l') }.should raise_error StateNode::PivotingOnConcurrentStateError
      end

      it 'should NOT throw an exception when the pivot state is the start state and is concurrent' do
        root.goto('/a/e/g/h/i', '/a/e/g/k/l')
        root.all_active_paths.should == ['/a/e/g/h/i', '/a/e/g/k/l']
        -> { g.goto('./h/j')}.should_not raise_error 
      end

      it 'should throw an exception when given an INVALID path' do
        -> { c.goto('/a/b/x') }.should raise_error StateNode::CannotResolveError
      end

      it 'should throw an exception when given paths to multiple clustered states' do
        -> { c.goto('/a/e/f/', '/a/e/g') }.should raise_error StateNode::EnterMultipleSubstatesError
      end

      it 'should handle directory-like relative paths' do
        root.all_active_paths.should == ['/a/b/c']
        c.goto '../d'
        root.all_active_paths.should == ['/a/b/d']
        d.goto '../../e/f'
        root.all_active_paths.should == ['/a/e/f']
        f.goto './../../b/./d/../c'
        root.all_active_paths.should == ['/a/b/c']
        c.goto '../../e/g/h/j/../i', '../../e/g/k'
        root.all_active_paths.should == ['/a/e/g/h/i','/a/e/g/k/l']
      end
    end
  end
end
