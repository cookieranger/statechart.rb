require 'enter_state_fns'
require 'event_fns'

require 'json'
require 'pp'

def uniq_states(states)
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
  include EnterStateFunctions
  include EventFunctions

  attr_accessor *%i{
    name substate_map substates superstate enters exits events concurrent history deep __is_current__ __cache__ 
    __transitions__ trace 
    __condition__ can_exit
  }

  class ConcurrentHistoryError < ArgumentError; end
  class ConcurrentStateCannotHaveConditionError < ArgumentError; end
  class CannotResolveConditionPathError < StandardError; end
  class CannotResolveError < StandardError; end
  class EnterMultipleSubstatesError < StandardError; end
  class InactiveStateError < StandardError; end
  class MultiplePivotError < StandardError; end
  class PivotingOnConcurrentStateError < StandardError; end
  class PivotingToDifferentStatechartError < StandardError; end

  # event errors
  class SendEventToInactiveStateError < StandardError; end
  

  alias_method :n, :name

  # Public: Convenience method for creating a new statechart. Simply creates a root state and invoke given function on that state.
  # opts - object of options to pass to StateNode constructor
  # callback - post create hook
  def self.define(opts={}, &callback)
    self.new('__root__', opts, &callback)
  end

  def state(name, opts = {}, &callback)
    new_substate = (name.class == self.class) ?
      name : 
      self.class.new(name, opts, &callback)

    add_substate(new_substate)
    new_substate
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

    # mine
    @__condition__   = {}
    @can_exit        = nil

    callback.call(self) if callback
  end

  # Status methods
  def root?() @name === '__root__'; end
  def concurrent?() @concurrent; end
  def history?() @history end
  def deep?() @deep end
  def __is_current__?() @__is_current__; end

  def __is_sending__?() @__is_sending__; end # not initialized


  def add_substate(state)
    # sets association and reverse assocation
    @substate_map[state.name.to_sym] = state;
    @substates << state;
    state.superstate = self

    # loop nested states, clear `@__cache__`, which is just `_path` of states
    # if this is deep, then set `@deep` and `@history` of all substates to `true`
    # if this is_attached? (its root has name '__root__'), invoke substate#did_attach, which is an empty function used by *RoutableState*
    state.for_each_descendant_states do |state|
      state.__cache__ = {};
      state.history = state.deep = true if self.deep?
      state.did_attach if root.is_root?
    end
    self
  end

  # equivalent to State#each
  def for_each_descendant_states(&callback)
    callback.call(self) if callback

    @substates.each do |substate|
      substate.for_each_descendant_states(&callback)
    end
  end
  
  # <Boolean> indicating whether or not the state at the given path is current, replica of statechart.js#isCurrent
  def current?(path = '.') 
    # check if {path} is resolvable from {thisState}
    state = resolve(path)
    !!state && state.__is_current__?
  end

  # Returns an array of paths to all current leaf states. replica of statechart.js#current
  def all_active_paths
    all_active_states.map(&:path)
  end

  # Returns an array of all current leaf states, replica of statechart.js#_current
  def all_active_states
    return [] unless __is_current__?
    return [self] if @substates.empty?

    @substates.reduce([]) do |arr, substate|
      arr.concat(substate.all_active_states) if substate.__is_current__? # concat mutates ;)
      arr
    end
  end
  
  # Resolves a string path into an actual `State` object, paths not starting with a '/' are resolved relative to the receiver state
  # Returns <State> if resolvable or 'nil'
  def resolve(path) 
    return nil if !path
    head, *path = path.class == String ? path.split('/') : path

    next_piece = case head
      when ''
        self.root
      when '.'
        self
      when '..'
        self.superstate
      else
        substate_map[head.to_sym] 
    end

    return nil if !next_piece
    
    # recursively call the next states.resolve method with remaining `path<Array>` until becomes [], then return the last path
    path.size === 0 ? next_piece : next_piece.resolve(path)
  end

  # Returns: a string containing the full path from the root state the receiver state
  def path
    '/' + path_states.map(&:name)[1..-1].join('/')
  end

  # Internal: Calculates and caches the path from the root state to the
  # receiver state. Subsequent calls will return the cached path array.
  # Returns an array of `State` objects.
  # NOTE: replica of statechart.js's `_path`, 
  # NOTE: private
  def path_states
    @__cache__[:path] ||= @superstate ? [*@superstate.path_states, self] : [self] # recursion
  end

  # Sets up a transition from the receiver state tot he given destination. 
  # all paths must be resolvable
  def goto(*paths_and_opts)
    if paths_and_opts.last.class == Hash
      *paths, opts = paths_and_opts
    else
      paths, opts = paths_and_opts, {}
    end
    
    # loop through `paths` called from goto to get states
    destination_states = paths.map do |p| 
      state = resolve(p)
      state ? state : raise(CannotResolveError, "State#goto could not resolve path #{p} from #{self}")
    end

    # loop through all states added, find pivots of current state(preferably root? though not always) and target state
    pivots = destination_states.map { |state| find_pivot(state) }

    # there should only be 1 uniq state in [pivots]
    if uniq_states(pivots).size > 1
      raise MultiplePivotError, "StateNode#goto: multiple pivot states found between state #{self} and paths #{paths.join(', ')}"
    end

    pivot = pivots[0] || self

    if pivot.can_exit?(destination_states, opts) === false 
      trace_state("State: [GOTO] : #{self} cannot exit")
      return false
    end
    trace_state("State: [GOTO] : #{self} -> [#{destination_states.join(', ')}]")

    # current state isn't active
    if (!__is_current__? && @superstate)
      raise InactiveStateError, "StateNode#goto: state #{self} is not current"
    end

    # if the pivot state is concurrent state and is NOT the current state (starting state), then we are attempting to cross a concurrency boundary.
    if (pivot.concurrent? && pivot != self)
      raise PivotingOnConcurrentStateError, "StateNode#goto: one or more of the given paths are not reachable from state #{self}: #{paths.join(', ')}"
    end

    # push transition to a queue `root.__transitions__`
    root.queue_transition(pivot, destination_states, opts)

    # flushes out all transitions queued up in `root.__transitions__`
    root.transition unless self.__is_sending__?

    true
  end

  # same as statechart.js#trace
  def trace_state(str)
    p str if false
  end

  # pending
  def queue_transition(pivot, states, opts)
    @__transitions__ << { pivot: pivot, states: states, opts: opts }
  end

  # Performs all queued transitions. This is the method that actually takes the statechart from one set of current states to another, the actual change. NOTE: private
  def transition
    return nil unless @__transitions__ && @__transitions__.any?
    @__transitions__.each do |trans|
      (_, pivot), (_, states), (_, opts) = *trans
      pivot.enter(states, opts)
    end
    @__transitions__ = []
  end

  # Loop from 0 to min(p1.length, p2.length) (which is like the depth), find common paths from the root of the two path and terminate loop when mismatch occurs
  # NOTE: private, part of goto,
  def find_pivot(other)
    p = nil
    p1, p2 = self.path_states, other.path_states
    depth_to_traverse = [p1.size, p2.size].min

    for i in 0...depth_to_traverse do
      if p1[i] == p2[i]
        # keep going down the depth and set the new p as long as hierarchy is overlapping
        p = p1[i] 
      else break 
      end
    end

    raise PivotingToDifferentStatechartError, "StateNode#find_pivot: states #{self} and #{other} do not belong to the same statechart" unless p
    p
  end

  # recursively find the root of this state by looking up superstate#root
  def root
    @__cache__[:root] ||= @superstate ? @superstate.root : self
  end

  # conditional state, used for consulting when entered a clustered state to determine destination states``
  def C(&callback) 
    raise ConcurrentStateCannotHaveConditionError, "StateNode#C: a concurrent state may not have a condition state: #{self}" if concurrent?

    @__condition__[:method] = callback
  end

  # come up with a different name for this, main_root?
  def is_root?() @name === '__root__'; end

  # Invoked by `#add_state`, currently only used by 'RoutableSTate' substate and should not be invoked by user
  def did_attach() end

  def attached?() root.is_root?; end

  def to_s() @name; end

  def view
    p "this is what this state #{name} look like"
    pp JSON.parse to_view.to_json
    nil
  end

  def to_view
    if @substates.any?
      @substates.reduce({}) do |hash, substate|
        modified_name = "#{substate.name}#{substate.concurrent? ? '.concur' : ''}#{substate.current? ? '.active' : ''}"
        hash[modified_name] = substate.to_view
        hash
      end
    else
      { leaf: true }
    end
  end

  # NOTE: private
  def can_exit?(destination_states, opts)
    @substates.map do |substate|
      if substate.__is_current__? && 
        substate.can_exit?(destination_states, opts) === false
        return false
      end
    end

    !@can_exit || @can_exit.(destination_states, opts)
  end
end