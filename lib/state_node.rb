def uniqStates(states)
  seen = {}; arr = [];
  
  for i in 0...states.size
    state = states[i]
    next unless state # falsy, meaning nil? or what?

    path = state.path
    if !seen[path]
      arr.push(state)
      seen[path] = true;
    end
  end
  arr
end

class StateNode
  attr_accessor *%i{
    name substate_map substates superstate enters exits events concurrent history deep __is_current__ __cache__ 
    __transitions__ trace
  }

  class ConcurrentHistoryError < ArgumentError; end

  # Public: Convenience method for creating a new statechart. Simply creates a root state and invoke given function on that state.
  # opts - object of options to pass to StateNode constructor
  # callback - post create hook
  def self.define(opts = {}, &callback)
    new_state = self.new('__root__', opts)
    callback.call(new_state) if callback
    new_state
  end

  def initialize(name, opts = {}, &callback)
    @name = name

    # TODO: smart argument recognizer, swap callback to opts if opts is function, and set opts to {}

    # can't be both 'concurrent' and 'History'
    if opts[:concurrent] && opts[:H]
      raise ConcurrentHistoryError, 'State: history states are not allowed on concurrent state.'    
    end
     
    @name            = name
    @substate_map    = {}
    @substates       = []
    @superstate      = nil
    @enters          = []
    @exits           = []
    @events          = {}
    @concurrent      = !!opts[:concurrent]
    @history         = !!opts[:H]
    @deep            = opts[:H] === '*'
    @__is_current__  = false
    @__cache__       = {}
    @__transitions__ = []
    @trace           = false

    callback.call(self) if callback
  end

  # Status methods
  def concurrent?() @concurrent; end
  def history?() @history end
  def deep?() @deep end


  def add_substate(state)
    # sets association and reverse assocation
    @substate_map[state.name.to_sym] = state;
    @substates << state;
    state.superstate = self

    # loop nested states, clear `@__cache__`, which is just `_path` of states
    # if this is deep, then set `@deep` and `@history` of all substates to `true`
    # if this is_attached? (its root has name '__root__'), invoke substate#did_attach, which is an empty function used by *RoutableState*
    state.for_each_substate do |state|
      state.__cache__ = {};
      state.history = s.deep = true if deep?
      state.did_attach if root.is_root?
    end
    self
  end

  # equivalent to State#each
  def for_each_substate(&callback)
    callback.call(self) if callback

    @substates.each do |substate|
      substate.for_each_substate(&callback)
    end
  end
  
  # <Boolean> indicating whether or not the state at the given path is current
  def current?(path = '.') 
    # check if {path} is resolvable from {thisState}
    state = resolve(path)
    !!state && state.__is_current__
  end
  
  def resolve(path) 
    # meed implementation
  end

  # recursively find the root of this state by looking up superstate#root
  def root
    @__cache__[:root] ||= @superstate ? @superstate.root : self
  end

  def is_root?() @name === '__root__'; end

  # Invoked by `#add_state`, currently only used by 'RoutableSTate' substate and should not be invoked by user
  def did_attach() end
end