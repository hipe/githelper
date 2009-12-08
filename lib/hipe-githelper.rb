#!/usr/bin/env ruby
require 'rubygems'
require 'hipe-gorillagrammar'
require 'hipe-gorillagrammar/extensions/syntax'


# This puppy is intended to be a standalone command line script written in ruby
# with useful features that are not out-of-the-box available for git -- Features like
# "add all files that haven't been added yet" or "add all files that have been modified"
# or "do an equivalent of svn-info.".  If you use this a lot, it is recommended that you do something like 
#   "alias gh='githelper' in your ~/.bash_profile"
#
# For example:
#   githelper info
#   githelper add modified and add untracked and delete deleted as dry run
#   githelper add both and delete deleted as dry run
#   githelper help
# 
#  Just for fun, the syntax of this command line tool is kind of strange in two ways:
#
#  1) instead of --options-like="this" or options like -abc, we just type them inline with the commands
#   so for example, we don't say "githelper add modified --dry-run" ,
#   we say "githelper add modified as dry run"
#  
#  2) the options can appear before or after the "verb phrase", so in addition to the above we could also say
#           "githelper as dry run add modified"
#
#
#  Wishlist: required verb modifiers.  utilize ruby 1.9 stuff
                        

module Hipe
  
  class GitHelper

    class BufferString < String # there was StringIO but i couldn't figure out how to use it
      def read
        output = self.dup
        self.replace('')
        output
      end
      def puts mixed
        if mixed.kind_of? Array
          mixed.each{|x| puts x}
        else
          self << mixed
          self << "\n" if (mixed.kind_of? String and mixed.length > 0 and mixed[mixed.size-1] != "\n"[0])
        end
      end
      public :puts
    end

    class Command
      def initialize name, desc, ast
        @name, @desc, @ast = name, desc, ast
      end
      def syntax; @symbol.syntax; end
      def help_short opts
        buffer = opts[:buffer] || ''
        col1width,col2width = opts[:col1width], opts[:col2width]
        syntax = sprintf(%{  %-#{col1width-3}s },@ast.syntax)
        buffer << syntax
        (buffer << ("\n" + ' ' * col1width )) if syntax.length > (col1width)
        buffer << self.class.wordwrap(@desc,col2width).gsub(/$\n/,"\n"+' '*col1width)
        buffer
      end
      def self.wordwrap text, line_width  # thanks rails
        text.split("\n").collect do |line|
          line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1\n").strip : line
        end * "\n"
      end
    end
    
    class GitHelperException < Exception; end    

    @screen = {:col1width=>26, :col2width=>46}
    VERSION = '0.0.1beta'
    REGGIE =
     %r< 
      (?:^\#\sOn\sbranch.*$\n)
      (?:^\#\sYour\sbranch\sis\sahead[^\n]+\n\#\n)?
      (?:^\#\s^\#\sInitial\sCommit\n\#\s)?
      (?:
        (?:^\#\sChanges\sto\sbe\scommitted:$\n)
        (?:^\#\s+[[:print:]]+$\n)+
        (?:^\#$\n)
        ((?:^\#\s+(?:new\sfile|modified|deleted|renamed|copied|[a-z ]+):\s+.+$\n)+)
        (?:^\#$\n)                       
      )?
      (?:
        (?:^\#\sChanged\sbut\snot\supdated:$\n)
        (?:^\#\s+[[:print:]]+$\n)+
        (?:^\#$\n)
        ((?:^\#\s+(?:modified|deleted):\s+.+$\n)+)
        (?:^\#$\n)                       
      )?  
      (?:
        (?:^\#\sUntracked\sfiles:$\n)
        (?:^\#\s+[[:print:]]+$\n)+
        (?:^\#$\n)
        ((?:^\#\s+.+$\n)+)
      )?        
      >ix  
    @grammar = Hipe.GorillaGrammar {
      :help_command    =~ 'help'
      :info_command    =~ 'info'
      :version_command =~ 'version'
      :delete_command  =~ ['delete',zero_or_one('deleted')]
      :add_command     =~ ['add',one('untracked','modified','both')]
      :command         =~ :add_command | :delete_command | :help_command | 
                          :version_command | :info_command
      :dry             =~ zero_or_one([zero_or_one('as'),'dry',zero_or_one('run')])                          
      :argv            =~ [:command,zero_or_more(['and',:command]),:dry]
    }
    
    class << self
      attr_accessor :commands, :grammar, :screen
    end
    
    @commands = []
    def self.command name, *other, &block
      @commands << Command.new(name, other[0], @grammar[(name.to_s+'_command'.to_s).to_sym])
    end
    
    def initialize(opts={})
      opts = {:output_buffer => $stdout }.merge opts
      @out = opts[:output_buffer]
    end

    def program_name;  File.basename($PROGRAM_NAME) end

    def run 
      self << ARGV
    end

    def << (argv)
      tree = parse_command argv
      execute_command tree
      @out
    end
    
    def read
      @out.read # will fail unless the user passed in something that responds to this.
    end
    
    def parse_command argv
      if (0==argv.size || ['--help','-h'].include?(argv[0])) then argv[0] = 'help'
      elsif (['-v','--version'].include?(argv[0])) then argv[0] = 'version'
      end
      tree = self.class.grammar.parse argv
      tree
    end
    
    def execute_command tree
      if tree.is_error?
        @out.puts tree.message 
        @out.puts "Please try 'help' for syntax and usage."
      else
        commands = tree.recurse {|x| (x.name.to_s =~ /_command$/) ? [x] : [] }
        dry      = tree.recurse {|x| (x.name.to_s =~ /dry/) ? [x] : [] }
        commands.each do |x| 
          send(x.name.to_s.match(/^(.+)_command$/).captures[0],[x,dry]) 
        end
      end
      @out      
    end

    command :help, "show this screen"
    def help args
      argv = self.class.grammar[:argv].fork_for_parse # make a deep copy,
      dry = argv.instance_variable_get('@group').pop.dereference # explain dry separately
      argv_syntax = %{#{argv.syntax} #{dry.syntax}}
      @out << <<-END.gsub(/^ {6}/, '')
      Helpful little shortcuts for git.
      usage: #{program_name} #{argv_syntax}
      
      available commands:
      END
      @out << self.class.commands.map{ |x| x.help_short(self.class.screen) }.join("\n")
      @out << "\n\n"
      @out << "available options:\n"+Command.new(:dry,
      "Don't actually do anything, just show a preview of what you would do (where applicable.)", dry).
      help_short(self.class.screen)
      @out << "\n"
    end
    
    command :version, "show version number of this script" 
    def version args
      @out.puts %{#{program_name} version #{VERSION}}
    end
    
    command :add, "add all files of that kind"
    def add tree
      is_dry = tree[1].size > 0 && tree[1][0].name == :dry
      do_untracked = ['both','untracked'].include? tree[0][1][0]
      do_modified  = ['both','modified'].include? tree[0][1][0]
      tree = git_status_parse_tree
      raise GitHelperException("failed to parse command") unless do_untracked || do_modified
      list = {}
      list[:modified] = do_modified ? tree[:changed]['modified'] : [] # names are strings!
      list[:untracked] = do_untracked ? tree[:untracked] : []
      [:modified,:untracked].each do |which|
        count = ( list[which] && list[which].size ) ? list[which].size : 0
        @out << %{# adding #{count} #{which.to_s} file(s)#{(is_dry&&count>0)? ' (dry run -- not actually doing it)' : '' }\n}
        next if count == 0
        list[which].each do |filename| 
          cmd = %{git add #{filename}}
          @out.puts cmd
          unless is_dry
            if (res = shell!(cmd)).length > 0
              raise GitHelperException.new(%{I wasn't expecting any response from this.  Got: "#{res}"})
            end
          end
        end
      end
      @out.puts '# done.'
    end
    
    def shell! cmd
      %x{#{cmd}}      
    end

    def git_status_string
      shell! 'git status'
    end

    def try_to_write_git_status_to_file(str)
      i = 0
      head = File.expand_path(FileUtils.pwd)+'/example'
      tail = '.git.status'
      begin
        filename = %{#{head}#{i+=1}#{tail}} 
      end while File.exist?(filename)
      e = nil
      File.open(filename, 'w'){|fh| fh.write(str)} rescue e
      e ? e.message : %{Wrote git status to "#{filename}".}
    end
    
    def git_status_parse_tree
      str = self.git_status_string
      unless (matches = REGGIE.match str)
        response = try_to_write_git_status_to_file(str)
        raise GitHelperException.new(%{Sorry, failed to parse the git status string.  Please make a note }+
        %{of the git status for a bug report. #{response}})        
      end
      caps = matches.captures
      ret = {
        :pending   =>  _to_hash(caps[0]),
        :changed   =>  _to_hash(caps[1]),
        :untracked =>  caps[2] ? caps[2].scan(/^\#\t(.*)$\n/).flatten : []
      }
      ret
    end
    
    def _to_hash(mixed)
      mixed ||= ''
      hash = Hash.new{|x,y|x[y] = []}
      x = mixed.scan(/^\#\t([^:]+): +(.*)$\n/)
      x.each{|pair| hash[pair[0]] << pair[1] }
      hash
    end

    command :info, "Similar to svn info (Thanks Duane Johnson!)"
    # This is a port of Duane Johnson's shell script (duane D0T johnson AT gmail D0T com, License: MIT): 
    # http://blog.inquirylabs.com/2008/06/12/git-info-kinda-like-svn-info/
    # Based on discussion at http://kerneltrap.org/mailarchive/git/2007/11/12/406496
    def info args
      # Find base of git directory
      until Dir.glob('.git').length > 0 do
        if '/'==Dir.pwd   
          @out.puts "can't find .git directory this or any parent folder!"
          return
        end
        Dir.chdir('..')
      end

      @out.puts "(in "+Dir.pwd+')'

      # Show various information about this git directory
      @out.puts "== Remote URL: "
      @out.puts `git remote -v`

      @out.puts "== Remote Branches: "
      @out.puts `git branch -r`

      @out.puts "== Local Branches:"
      @out.puts `git branch`
      @out.puts "\n"

      @out.puts "== Configuration (.git/config)"
      File.open('.git/config'){|fh| @out.puts fh.read }
      @out.puts "\n"

      @out.puts "== Most Recent Commit"
      @out.puts `git log --max-count=1`
      @out.puts "\n"

      @out.puts "Type 'git log' for more commits, or 'git show' for full commit details."
      
    end
  
  end # class GitHelper
  
end # module Hipe

# pz.to_enum.with_index.select{|e,i| e > 5 }.map{|e,i| i } from manveru sunday 18:08    
# we considered using Diff::LCS.LCS for this but -- we need contiguous matches