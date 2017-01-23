module EnterStateFunctions
  def upon_enter(&callback)
    @enters << callback
    self
  end

  def upon_exit(&callback)
    @exits << callback
    self
  end

  # Enters the receiver stat,  NOTE: private
  def enter(states, opts)
    concurrent? ? enter_concurrent(states, opts) : enter_clustered(states, opts)
  end

  # Enters a clustered state NOTE: private
  def enter_clustered(states, opts)
    selflen = path_states.size

    # find the first active substate and set to cur, break
    current_active_substate = @substates.find {|state| state.__is_current__? } 

    # ???for each states, push the ? current level of depth of substate
    nexts = states.reduce([]) { |arr, state| arr << state.path_states[selflen] }

    # throws error, if [nexts] has multiple
    if uniq_states(nexts).size > 1
      raise StateNode::EnterMultipleSubstatesError, "StateNode#enter_clustered: attempted to enter multiple substates of #{self}: #{nexts.join(', ')}"
    end

    # if there is no nexts but there are substates in this, determine the next state priority:
    # 1. Conditions, 2. History, 3. First Substate
    if !(next_state = nexts.first) && @substates.any?

      # if a this.C (condition state function) is defined and calling it gets truthy paths, flatten those paths
      condition_state_callback = @__condition__[:method]
      if condition_state_callback && (paths = condition_state_callback.(opts[:context]))
        # for all [paths], check if path is resolvable (from this), put onto states
        states = [paths].flatten.reduce([]) do |arr, path|
          if !(state = resolve(path))
            raise StateNode::CannotResolveConditionPathError, "StateNode#enter_clustered: could not resolve path '#{path}' returned by condition function from #{self}"
          end
          arr << state
        end

        return enter_clustered(states, opts)
      end

      next_state = @__previous__ if history? # else if history exist, set `next` to `previous`, going back

      next_state = @substates.first unless next_state # else set next to first substate
    end

    current_active_substate.exit(opts) if current_active_substate && current_active_substate != next_state # if `cur` isn't next, call cur.exit(opts)

    # if state is not currently active state or if option has { force: true }, set current active state to { true } and call `this.call_enter_handler(opts[:context])`
    # byebug
    if !__is_current__? || opts[:force]
      trace_state("State: [ENTER] : #{self.path} #{__is_current__? && '(forced)'}")
      @__is_current__ = true
      call_enter_handler(opts[:context])
    end

    # if theres a next at this point (which is likely), enters the receiver state with next.enter(states, opts)
    next_state.enter(states, opts) if next_state

    self
  end

  # NOTE: private
  # Enters a concurrent state. Simply involes calling the `enter` method on the receiver and recursively entering each substate.
  def enter_concurrent(destination_states, opts)
    # if there isn't already active or if force entering, enter by setting { __is_current__ } to true
    if !__is_current__? || opts[:force]
      trace_state("StateNode: [ENTER] : #{path} #{__is_current__? && '(forced)'}")
      @__is_current__ = true
      call_enter_handler(opts[:context])
    end

    valid_destination_states = []

    # Loop over all substates
    # nest another loop to loop over destination states
    # -> check if substates and destination states pivots at substate 
    # (basically checking if targeted state is stemmed from this (concurrent) state)
    @substates.map do |substate|
      valid_destination_states = destination_states.select do |d_state|
        substate.find_pivot(d_state) == substate
      end
      substate.enter(valid_destination_states, opts)
    end

    self
  end

  def call_enter_handler(opts_context)
    @enters.each {|enter_fn| enter_fn.(self, opts_context) }
  end

  def call_exit_handler(opts_context) 
    # byebug
    @exits.each {|exit_fn| exit_fn.(self, opts_context) }
  end

  # pending implementation
  def can_exit?(states, opts)
    true
  end

  # resets the statechart by exiting all current states
  def reset
    exit({})
  end

  def exit(opts)
    concurrent? ? exit_concurrent(opts) : exit_clustered(opts)
  end

  # Exits a concurrent state, recursively exit each substate and invoke the exit method as stack unwinds
  def exit_concurrent(opts)
    @substates.each { |substate| substate.exit(opts) }
    call_exit_handler(opts[:context])
    @__is_current__ = false
    trace_state("State: [EXIT] : #{self.path}") if self != root
    self
  end

  attr_accessor :__previous__

  # Exits a clusterd state. Exiting happens bottom to top, so we recursively exit the current substate and then invoke the exit method on each state and stack unwinds
  def exit_clustered(opts)
    cur = @substates.find {|substate| substate.__is_current__? }

    # if history: true for current state, set current states `__previous__` to active substate
    # NOTE: `cur` could potentially be undefined
    @__previous__ = cur if history?

    cur.exit(opts) if cur

    call_exit_handler(opts[:context])
    @__is_current__ = false
    trace_state("State: [EXIT] : #{self.path}")

    self
  end

end
