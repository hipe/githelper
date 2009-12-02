# ruby test/all_test.rb
require 'rubygems'
require 'ruby-debug'
require File.dirname(__FILE__)+'/teststrap'


# dangerous -- we pass anything to shell and execute it to see how the shell parses it
def shell! str
  Marshal.load %x{ruby #{File.dirname(__FILE__)}/argv #{str}}
end

class BufferString < String; def flush; t = s.dup; s.replace(''); t end end

context "parsing input" do
  #setup do
  #  @s = BufferString.new
  #  Githelper.new(:output_buffer=>@s)
  #end
  #
  #asserts("displays help when given empty input") do
  #  
  #end
  #  
  #  
  #end
      
end



Hipe::GitHelper.new(:output_buffer=>@s).git_status_parse_tree

context "parsing git status" do
  setup do
    
    debugger
   #@s = BufferString.new 
   #@g = Hipe::GitHelper.new(:output_buffer=>@s)
   #def @g.git_statuz_string
   #  File.open(File.dirname(__FILE__)+'/example1.git.status','r'){|f| f.read}
   #end
   #
  end
  
  asserts("parses the git file into a pretty tree"){ 
    debugger
    @g.git_status_parse_tree
    
    
     }
end