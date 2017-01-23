describe 'weird spec test' do
  let(:arr) { [] }
  let(:arr_pointer) { arr }
  let(:arr2) { [] }
  def inc() arr << 1; arr2 << 1; end
  it 'should pass' do
    inc
    arr, arr2 = [], []
    arr.size.should == 0 # this works, but it is pointing to the new array
    arr.should_not === arr_pointer # yep, this is NOT ====
    inc
    arr.size.should == 0 # actually gotten 0 b/c the arr in the #inc points to the original array
    arr_pointer.size.should == 2 # gotten hold of the original arr, which is now size 2
  end
end