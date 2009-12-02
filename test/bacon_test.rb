# bacon test/bacon_test.rb
# WARNING! currently this uses the shell to see exactly how the shell will parse a string 
# and turn it into an array.  These tests will likely fail on windows. @FIXME


require 'rubygems'
require 'hipe-githelper'
require 'bacon'

##################################
module TestHelper
 # dangerous! -- we pass anything to shell and execute it to see how the shell parses it
  @argv_filename = %{#{File.expand_path(File.dirname(__FILE__))}/argv.rb}
  class << self
    attr_accessor :argv_filename
  end
  def shell! str
    response = %x{ruby #{TestHelper.argv_filename} #{str}}    
    Marshal.load response
  end    
end
include TestHelper
#################################

include TestHelper

describe "Parsing user input in General context" do
  
  before do
    @g = Hipe::GitHelper.new(:output_buffer=>(@s = Hipe::GitHelper::BufferString.new))    
  end
  
  it "should help on no input (b1)" do
    @g << shell!('')
    @g.read.should.match( /usage[^\n]+(\n[^\n]*){5}/ )
  end
  
  it "should complain on bad input (b2)" do
    @g << shell!('bling blang blong')
    @g.read.should.match( /don't know what you mean by .*bling.*expecting.*help/)
  end
  
  it "should do version command (b3)" do
    @g << shell!('version')
    @g.read.should.match( /version.*\d+\.\d+\.\d/)
  end
end

describe Hipe::GitHelper::BufferString,"in General context" do
  it "puts should work with arrays" do
    s =  Hipe::GitHelper::BufferString.new
    s.puts(['alpha','beta'])
    s.read.should.equal "alpha\nbeta\n"
  end
end


describe 'Actual script in real environment, in General context' do
  before do
    @g = Hipe::GitHelper.new(:output_buffer=>(@s = Hipe::GitHelper::BufferString.new))    
  end  

  it "should report in actual status (Fragile test--needs actual git repository) (r1)" do # was p3
    @g << shell!('info');
    @g.read.should.match(
      /Remote URL.*== Remote Branches.*== Local Branches.*== Configuration.*== Most Recent Commit.*/m
    )
  end
  
  it "should do add as dry run (Fragile test--needs actual git repository)(r2)" do     
    @g << shell!('add modified as dry run')
    s = @g.read
    s.should.match(/^# adding /)
  end
  
  it "should actually run from the command line (r3)" do
    fullpath = File.expand_path(File.dirname(__FILE__))+'/../bin/githelper'
    %x{#{fullpath} version}.should.match(/version.*\d+\.\d+\.\d+/i)
  end
  
  
  it "should complain about missing git, or that ...blah blah(p6)" do
    # "YOU'RE GOING TO FEEL REALLY DUMB WHEN THIS FAILS"
    @app = Hipe::GitHelper.new
    class << @app; self end.send(:define_method,'shell!'){'dummy response for testing'} # metaprogramming just for fun\
    def @app.git_status_string # @todo fixme -- this needs actual stubbing or mocking or whatever
      File.open(File.dirname(__FILE__)+'/example1.git.status','r'){|f| f.read}
    end    
    fn = 'erase-me-now-'+Time.now.strftime('%Y-%m-%d--%H:%I:%S')
    FileUtils.touch fn
    lambda{ @app << shell!('add untracked') }.should.raise(Hipe::GitHelper::GitHelperException).
      message.should.match(/^I wasn't expecting any response from this\.  Got: "dummy response for testing"$/)
    FileUtils.rm fn
  end
  
end

describe 'Parsing the git status in General context' do
  before do
    @app = Hipe::GitHelper.new :output_buffer=>Hipe::GitHelper::BufferString.new
    def @app.git_status_string # @todo fixme -- this needs actual stubbing or mocking or whatever
      File.open(File.dirname(__FILE__)+'/example1.git.status','r'){|f| f.read}
    end
  end

  it "parses the git file into a pretty tree (p1)" do
    @app.git_status_parse_tree.should.equal({
    :pending=>
     {"modified"=>["lib/hipe-gorillagrammar.rb", "spec/parsing_spec.rb"],
      "deleted"=>["spec/unparse_spec.rb"]},
    :changed=>
     {"modified"=>
       ["History.txt",
        "README.txt",
        "lib/hipe-gorillagrammar.rb",
        "spec/parsing_spec.rb",
        "spec/sequence_spec.rb",
        "spec/shorthand_spec.rb"]},
      :untracked=>
      ["lame",
       "oh.rb",
       "spec/FOCUS",
       "spec/parse_tree_spec.rb",
       "spec/symbol_reference_spec.rb"]
    })
  end
  
  it "should do add as dry run (p2)" do     
    @app << shell!('add modified as dry run')
    s = @app.read
    s.should.match(/add.*History.*README.txt\n(.*\n){3}/m)
  end  
  
  it "should complain when not in git dir (p4)" do
    name = '/tmp/this_is_a_temporary_folder_for_tests'
    pwd = Dir.pwd
    FileUtils.mkdir name unless File.exist?(name)
    FileUtils.cd name 
    @app << shell!('info')
    FileUtils.cd pwd 
    @app.read.should.match(/can't find \.git directory this or any parent folder!/)
  end
  
  it "should write that file thing.(p5)" do
    str = "this is a bad git status string for the purpose of testing"
    class << @app; self end.send(:define_method,:git_status_string){str}  # thanks rue
    begin
      @app.git_status_parse_tree    
    rescue Hipe::GitHelper::GitHelperException => e
      md = /Wrote git status to "([^"]+)"/.match(e)
      md.should.be.kind_of MatchData
      str.should.equal File.open(md[1],'r'){|fh| fh.read } # ridiculous test
    end
  end
end
