module EventFunctions

  # Register an event handler to be called when an event with a matching name is sent to the state via the `send` method.
  # Only one handler may be registered per event
  def event(event_name, &event_handler)
    @events[event_name.to_sym] = event_handler
    self
  end

  # sends an event to teh statechart, which gives each current leaf state an opportunity to handle it, events bubble up superstate chain until a handler method return a truthy value.
  # Returns a boolean indicating whether or not the event was handled
  def send_event(event_name, *args)
    handled = nil

    if (!__is_current__?)
      raise StateNode::SendEventToInactiveStateError, "StateNode#send: attempted to send an event to a state that is not current: #{self}"
    end

    # if this is root, log 
    trace_state("StateNode: [EVENT] : #{event_name}") if root?

    handled = concurrent? ? 
      send_concurrent(event_name, *args) :
      send_clustered(event_name, *args)

    # if NOT handled and current state registered a function with teh same event_name,
    # hail mary shot by applying that event to `self` with remaining args, with `__is_sending__` flag set so any queued transition will be triggered along the way
    if (!handled && @events[event_name.to_sym])
      @__is_sending__ = true
      handled = @events[event_name.to_sym].(self, *args)
      @__is_sending__ = false
    end

    transition if !@superstate # on root state, or state no parent

    handled
  end

  def send_concurrent(event_name, *args)
    # only handled if all substate send the events returning true
    handled = @substates.map do |substate|
      substate.send_event(event_name, *args)
    end.uniq == [true]
  end

  def send_clustered(event_name, *args)
    handled = false
    first_active_substate = @substates.find(&:__is_current__?)

    if first_active_substate
      handled = first_active_substate.send_event(event_name, *args)
    end

    handled
  end

end