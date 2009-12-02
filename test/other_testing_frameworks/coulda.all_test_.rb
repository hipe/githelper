require 'rubygems'
require 'coulda'
require 'hipe-githelper'
include Coulda

module Helper
  def get_app
    Githelper.new(:output_buffer=>'')
  end
  
  def shell_argv! string
    Marshal.load %x{ruby #{File.dirname(__FILE__).'/argv.rb'}}
  end
  
end

Feature "Parse user commands" do
  include helper
  in_order_to "understand user requests"
  as_a "pieces of software"
  i_want_to "use an LA parser generator to understand commands"
  
  Scenario "the user enters nothing" do
    Given "the user inputs this" do 
      @app = get_app
      @argv = shell_argv! ''
    end
    When "i parse it" do
      @app << @argv
    end
    Then "it should make a pretty tree" do 
      assert_match /usage.*\n.*\n.*\n/i, @app->flush
    end
  end
end