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

  describe '.define' do
    it 'should create a root state with the name `__root__`' do
      s = StateNode.define
      s.superstate.should == nil
      s.name.should == '__root__'
    end

    it 'should pass the options to the `StateNode` constructor' do
      s = StateNode.define(concurrent: true)
      s.concurrent?.should == true
    end

    it 'should call the given function in the context of the newly created state' do
      ctx = nil
      s = StateNode.define(&->(state) { ctx = state})
      ctx.should == s
    end
  end

  describe '#root?' do
    it 'returns true for the node returned by StateNode.define' do
      StateNode.define.root?.should == true
    end

    it 'returns FALSE for all other states' do
      stateA = StateNode.new 'a'
      stateB = StateNode.new 'b'
      StateNode.define.add_substate(stateA).add_substate(stateB).root?.should == true
      stateA.root?.should == false
      stateB.root?.should == false
      StateNode.new('we').root?.should == false
    end
  end

  describe '#state' do
    let(:root) { StateNode.define }
    it 'should create a substate with the given name on the receiver' do
      x = root.state('x')
      x.class.should == StateNode # hmm. === doesn't work here
    end

    it 'should pass the options to the `State` constructor' do
      x = root.state('x', concurrent: true)
      x.concurrent?.should === true
    end

    it 'should call the given function with teh newly created state' do
      context = nil
      x = root.state('x', concurrent: true, &->(ctx) { context = ctx})
      context.should === x
    end

    describe 'when given a `State` instance' do
      it 'should add the given state as a substate' do
        s = StateNode.new('s')
        root.state(s)
        root.substates.should =~ [s]
      end
    end
  end

  describe '#resolve' do
    let(:root)  { StateNode.new('root') }
    let(:s)     { StateNode.new('s') }
    let(:s1)    { StateNode.new('s1') }
    let(:s2)    { StateNode.new('s2') }
    let(:s11)   { StateNode.new('s11') }
    let(:s12)   { StateNode.new('s12') }
    let(:s21)   { StateNode.new('s21') }
    let(:s22)   { StateNode.new('s22') }

    before do      
      root.add_substate(s);
      s.add_substate(s1);
      s.add_substate(s2);
      s1.add_substate(s11);
      s1.add_substate(s12);
      s2.add_substate(s21);
      s2.add_substate(s22);
    end

    it 'should return the state object at the given full path from the root state' do
      root.resolve('/s').should == s
      root.resolve('/s/s1').should == s1
      root.resolve('/s/s2/s22').should == s22
    end

    it 'should return the state object at the given relative path from the root state' do
      root.resolve('s').should == s
      root.resolve('s/s1').should == s1
      root.resolve('s/s1/../s2').should == s2
    end

    it 'should return the state object at the given full path from a child state' do
      s12.resolve('/s').should == s
      s22.resolve('/s/s1').should == s1
      s21.resolve('/s/s2/s22').should == s22
    end

    it 'should resolve the state object at the given relative path from a child state' do
      s1.resolve('s12').should == s12
      s1.resolve('s11').should == s11
      s22.resolve('../..').should == s
      s22.resolve('../../..').should == root
    end

    it 'should return nil when given an invalid path' do
      root.resolve('/a/b/x').should == nil
    end

    it 'should return nil when given given nil' do
      root.resolve(nil).should == nil
    end
  end

  describe 'Subclass of State' do
    class CustomState < StateNode
    end

    describe 'CustomState.define' do
      it 'creates instances of CustomState' do
        CustomState.define.class.should == CustomState
      end
    end

    describe 'CustomState#state' do
      it 'creates instances of CustomState' do
        CustomState.define.state('x').class.should == CustomState
      end
    end
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
    describe '#enter#exit handlers - Independent test' do
      let(:enter_a) { StateNode.new('enterA') }
      let(:enter_b) { StateNode.new('enterB') }
      let(:enter_c) { StateNode.new('enterC') }
      let(:enter_1) { StateNode.new('enter1') }
      let(:enter_2) { StateNode.new('enter2') }
      let(:enter_3) { StateNode.new('enter3') }
      let(:enter_root) {StateNode.new('enterRoot') }
      let(:enter_col) { [] }

      before do
        enter_root.add_substate(enter_a).add_substate(enter_1)
        enter_a.add_substate(enter_b).add_substate(enter_c)
        enter_1.add_substate(enter_2).add_substate(enter_3)

        [enter_a, enter_b, enter_c, enter_1, enter_2, enter_3].each do |st|
          st.upon_enter do |s|
            enter_col << s
          end
        end
      end

      it 'should invoke when entered' do
        enter_root.goto
        enter_root.all_active_paths.should =~ ['/enterA/enterB']
        enter_col.should =~ [enter_a, enter_b]

        enter_root.goto('/enter1')
        enter_root.all_active_paths.should =~ ['/enter1/enter2']
        enter_col.should =~ [enter_a, enter_b, enter_1, enter_2]

        enter_root.goto('/enter1/enter3')
        enter_col.should =~ [enter_a, enter_b, enter_1, enter_2, enter_3]
      end
    end

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
    describe 'StateNode#goto and Enter Exit handlers' do
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
      let(:enters) { [] }
      let(:exits) { [] }

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
        [root, a, b, c, d, e, f, g, h, i, j, k, l, m].each do |state|
          state.upon_enter { |s| enters << s.name }
          state.upon_exit { |s| exits << s.name }
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
        root.all_active_paths.should =~ ['/a/e/g/h/i','/a/e/g/k/l']
      end

      describe '#upon_enter and #upon_exit tests' do  
        it 'should exit the states leading up to the pivot state and enter the states leading to the destination states' do
          c.goto('/a/e/f')
          root.all_active_paths.should == ['/a/e/f']
          exits.should =~ ['c','b']
          enters.should =~ ['e','f']

          enters.clear
          exits.clear

          f.goto('/a/e/g/h/i', '/a/e/g/k/m')
          root.all_active_paths.should == ['/a/e/g/h/i', '/a/e/g/k/m']
          exits.should =~ ['f']
          enters.should =~ ['g', 'h', 'i', 'k', 'm']
        end

        it 'should set `__is_current__` to `true` on all states entered and to `false` on all states exited' do
          [a,b,c,e,f].map(&:__is_current__?).should == [true, true, true, false, false]

          c.goto('/a/e/f')
          [a,b,c,e,f].map(&:__is_current__?).should == [true, false, false, true, true]
        end

        it 'should enter the default substate when a path to a leaf state is not given' do
          c.goto('/a/e/g')
          enters.should == %w(e g h i k l)
        end

        it 'should exit all substates when a concurrent superstate is exited' do
          c.goto('/a/e/g/h/j', '/a/e/g/k/l')

          exits.clear
          g.goto('/a/b/d')
          exits.should == %w(j h l k g e)
        end

        it 'should enter all substates when a concurrent superstate is entered' do
          c.goto('/a/e/g')
          enters.should == %w(e g h i k l)
        end

        it 'should not affect the states in concurrent superstates' do
          c.goto('/a/e/g/h/j', '/a/e/g/k/m')

          exits.clear
          enters.clear

          m.goto('/a/e/g/k/l')
          exits.should == ['m']
          enters.should == ['l']
        end

        it 'should enter the most recently exited substate when the path is not specified and the state has history tracking' do
          root.all_active_paths.should == ['/a/b/c']
          c.goto '/a/b/d'
          root.all_active_paths.should == ['/a/b/d']
          d.goto '/a/e/f'
          root.all_active_paths.should == ['/a/e/f']
          f.goto '/a/b'
          root.all_active_paths.should == ['/a/b/d'] # remembers D, horray!
        end

        it 'should enter the most recently exited leaf states when the path is NOT specified and the state has deep history tracking' do
          root.goto('/a/e/g/h/j', '/a/e/g/k/m')
          root.all_active_paths.should == ['/a/e/g/h/j', '/a/e/g/k/m']
          root.goto('/a/b/c')
          root.all_active_paths.should == ['/a/b/c']
          root.goto('/a/e')
          root.all_active_paths.should == ['/a/e/g/h/j', '/a/e/g/k/m']
        end

        # Enter exit
        it 'should pass along its `context` option to each entered states `enter` method' do
          e_ctx, f_ctx = nil, nil
          e.upon_enter {|state, context| e_ctx = context}
          f.upon_enter {|state, context| f_ctx = context}
          c.goto('/a/e/f', context: 'foo')

          e_ctx.should == 'foo'
          f_ctx.should == 'foo'
        end

        it 'should invoke all other handlers registered on the state' do
          calls = []
          e.upon_enter { calls << 1}
          e.upon_enter { calls << 2}
          e.upon_enter { calls << 3}
          c.goto('/a/e/f')
          calls.should == [1,2,3]
        end

        it 'should pass along its `context` option to each exited states `exit` method' do
          b_ctx, c_ctx = nil, nil
          b.upon_exit { |state, context| b_ctx = context }
          c.upon_exit { |state, context| c_ctx = context }
          c.goto '/a/e/f', context: 'bar'
          b_ctx.should == 'bar'
          c_ctx.should == 'bar'
        end

        it 'should invoke all exit handlers registered on the state' do
          calls = []
          b.upon_exit { calls << 1}
          b.upon_exit { calls << 2}
          c.goto '/a/e/f'
          calls.should == [1,2]
        end

        it 'should invoke `enter` methods on states that are already current when the `force` option is given' do
          c.goto '/a/e/f'
          enters.should == ['e', 'f']

          enters.clear
          root.goto('/a/e/f')
          enters.should == []

          root.goto '/a/e/f', force: true
          enters.should == %w(root a e f)
        end
      end
    end

    describe '#can_exit' do
      let(:root) { StateNode.new('root') }
      let(:stateA) { StateNode.new('a') }
      let(:stateB) { StateNode.new('b') }

      before do
        root.add_substate(stateA).add_substate(stateB).goto  
      end

      it 'blocks transition if it returns false' do
        stateA.can_exit = ->(*args) { false }
        root.goto '/b'
        root.all_active_paths.should == ['/a']
      end

      it 'does not block transition if it returns anything' do
        root.can_exit = ->(*args) { nil }

        root.goto('/b').should == true
        root.all_active_paths.should == ['/b']
      end

      it 'causes #goto to return false' do
        root.can_exit = ->(*args) { false }
        root.goto('/b').should == false
      end

      it 'gets called with the destination states, context and other opts' do
        args = []
        stateA.can_exit = ->(*arguments) { args = arguments }

        root.goto '/b', context: 'the context', force: true
        args.should =~ [
          [root.resolve('/b')], 
          context: 'the context', force: true
        ]
      end
    end

    describe 'condition states' do
      let(:root) { StateNode.new('root') }
      let(:x)    { StateNode.new('x') }
      let(:y)    { StateNode.new('y') }
      let(:z)    { StateNode.new('z', H: true) }
      let(:z1)   { StateNode.new('z1') }
      let(:z2)   { StateNode.new('z2') }
      let(:a)    { StateNode.new('a') }
      let(:b)    { StateNode.new('b') }
      let(:c)    { StateNode.new('c', concurrent: true) }
      let(:d)    { StateNode.new('d') }
      let(:e)    { StateNode.new('e') }
      let(:f)    { StateNode.new('f') }
      let(:g)    { StateNode.new('g') }
      let(:h)    { StateNode.new('h') }
      let(:i)    { StateNode.new('i') }

      before do
        root.add_substate(x)
        root.add_substate(a)
        root.add_substate(z)
        a.add_substate(b)
        a.add_substate(c)
        a.add_substate(y)
        c.add_substate(d)
        c.add_substate(e)
        d.add_substate(f)
        d.add_substate(g)
        e.add_substate(h)
        e.add_substate(i)
        z.add_substate(z1)
        z.add_substate(z2)

        root.goto
        root.all_active_paths.should == ['/x']
      end

      it 'should throw an exception when a condition state is defined on concurrent state' do
        -> {
          StateNode.new('x', concurrent: true).C(&->{})
        }.should raise_error StateNode::ConcurrentStateCannotHaveConditionError
      end

      it 'should throw an exception when the states returned by the condition function dont exist' do
        a.C(&->(arg){'./blah'})

        -> {root.goto('/a') }.should raise_error StateNode::CannotResolveConditionPathError
      end

      it 'should cause #goto to enter the state returned by teh condtiion function' do
        a.C(&->(arg) { './y' })
        root.goto '/a'
        root.all_active_paths.should == ['/a/y']
      end

      it 'should cause #goto to enter the first substate when null is returned by the condition function' do
        a.C(&->(arg) { nil })
        root.goto '/a'
        root.all_active_paths.should == ['/a/b']
      end

      it 'should cause #goto to use the history state when tis defined and the condition function returns null' do
        z.C(&->(arg) { nil })
        root.goto '/z/z2'
        root.all_active_paths.should == ['/z/z2']
        root.goto '/x'
        root.all_active_paths.should == ['/x']
        root.goto '/z'
        root.all_active_paths.should == ['/z/z2']
      end

      it 'should cause #goto to enter the states returned by the condition function' do
        a.C(&->(arg) { ['./c/d/g', '/a/c/e/i'] })
        root.goto '/a'
        root.all_active_paths.should == ['/a/c/d/g', '/a/c/e/i']
      end

      it 'should pass the context to the condition function' do
        passed_ctx= nil
        a.C do |ctx| 
          passed_ctx = ctx
          ['./c/d/g', '/a/c/e/i'] #anything string / array of string
        end

        root.goto('/a', context: [1,2,3])
        passed_ctx.should == [1,2,3]
      end

      it 'should NOT be called when destination states are given' do
        called = false
        a.C(&->(arg) { called = true; './adf/adsf/ads/f' })
        root.goto '/a/b'

        called.should == false
        root.all_active_paths.should == ['/a/b']
      end
    end

    describe '#send' do
      let(:root)  { StateNode.new('root', concurrent: true) }
      let(:a)     { StateNode.new('a') }
      let(:b)     { StateNode.new('b') }
      let(:c)     { StateNode.new('c') }
      let(:d)     { StateNode.new('d') }
      let(:e)     { StateNode.new('e') }
      let(:f)     { StateNode.new('f') }
      let(:calls) { [] }

      before do
        root.add_substate(a)
        a.add_substate(b)
        a.add_substate(c)
        root.add_substate(d)
        d.add_substate(e)
        d.add_substate(f)

        root.event('someEvent') { |ctx| calls << ctx; false }
        a.event('someEvent') { |ctx| calls << ctx; false }
        b.event('someEvent') { |ctx| calls << ctx; false }
        c.event('someEvent') { |ctx| calls << ctx; false }
        d.event('someEvent') { |ctx| calls << ctx; false }
        e.event('someEvent') { |ctx| calls << ctx; false }
        f.event('someEvent') { |ctx| calls << ctx; false }

        root.goto()
      end

      it 'precondition' do
        root.all_active_paths.should == ['/a/b', '/d/e']
      end

      it 'should pass additional arguments to the event handler' do
        all_args = nil
        b.event('someEvent', &->(*args) { all_args = args})
        root.send_event 'someEvent', 1, 2, 'foo'
        all_args.should === [b, 1, 2, 'foo']
      end

      it 'should bubble the event up each current states superstate chain' do
        root.send_event('someEvent')
        calls.map(&:name).should == %w(b a e d root)
      end

      # in ruby case, truthy value means true
      it 'should STOP bubbling when a ahandler on a clustered substate returns a truthy value' do
        state_root = StateNode.new('root')
        state_a = StateNode.new('a')
        state_b = StateNode.new('b')
        _calls = []

        state_root.add_substate(state_a)
        state_a.add_substate(state_b)
        state_root.goto

        state_root.event('someEvent') { |ctx| _calls << ctx; false }
        state_a.event('someEvent') { |ctx| _calls << ctx; true }
        state_b.event('someEvent') { |ctx| _calls << ctx; false }

        state_root.send_event('someEvent')
        _calls.map(&:name).should == ['b', 'a']

        _calls.clear
        state_b.event('someEvent') { |ctx| _calls << ctx; true }
        state_root.send_event('someEvent')
        _calls.map(&:name).should == ['b']
      end

      it 'should STOP bubbling when all handlers on a concurrent state return a truthy value' do
        a.event('someEvent') { |ctx| calls << ctx; true }
        root.send_event 'someEvent'
        calls.map(&:name).should == %w(b a e d root)

        root.goto
        calls.clear

        d.event('someEvent') { |ctx| calls << ctx; true }
        root.send_event 'someEvent'
        calls.map(&:name).should == %w(b a e d)
      end

      it 'should NOT perform transitions made in an event handler until all current states have received the event' do
        active_paths = []
        b.event('someEvent') { |state| state.goto('/a/c'); false }
        e.event('someEvent') { active_paths = root.all_active_paths; false }

        root.send_event('someEvent')

        root.all_active_paths.should == ['/a/c', '/d/e']
        active_paths.should == ['/a/b', '/d/e']
      end
    end

    describe '#reset' do
      it 'should exit all current states' do
        root = StateNode.define do |st|
          st.state('x') do |x|
            x.state('y')
            x.state('z')
          end
        end
        root.goto
        root.all_active_paths.should == ['/x/y']
        root.__is_current__?.should == true

        root.reset
        root.all_active_paths.should == []
        root.__is_current__?.should == false
      end
    end

    describe '#current?' do
      it 'returns true if the state at the given relative path is current and FALSE otherwise' do
        r = StateNode.new('')
        x = StateNode.new('x')
        y = StateNode.new('y')
        z = StateNode.new('z')

        r.add_substate(x)
        x.add_substate(y)
        x.add_substate(z)

        r.goto()

        r.current?('./x/y').should == true
        r.current?('./x/z').should == false
        y.current?('.').should == true
        y.current?('..').should == true
        z.current?('..').should == true
        z.current?('.').should == false
        z.current?('/x/y').should == true
        z.current?('/x/z').should == false
      end

      it 'should return false if the state DOES NOT exist' do
        StateNode.new('').current?('/x/y/z').should == false
      end
    end
  end
end
