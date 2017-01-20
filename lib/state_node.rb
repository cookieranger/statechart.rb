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

  def concurrent?() @concurrent; end
  def history?() @history end
  def deep?() @deep end
  
  # <Boolean> indicating whether or not the state at the given path is current
  def current?(path = '.') 
    # check if {path} is resolvable from {thisState}
    state = resolve(path)
    !!state && state.__is_current__
  end
  
  def resolve(path) end
end