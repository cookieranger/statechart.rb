class StateNode
  attr_accessor :name

  def initialize(name, opts, callback)
    @name = name
    opts ||= {}

    # TODO: smart argument recognizer, swap callback to opts if opts is function, and set opts to {}

    # can't be both 'conccurrent' and 'History'
    if opts[:concurrent] && opts[:H]
      raise ArgumentError.new('State: history states are not allowed on concurrent state.')
    end
  end
end
