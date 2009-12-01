#!/usr/bin/env ruby

# This puppy is intended to be a standalone command line script written in ruby
# with useful features that are not out-of-the-box available for git -- Features like
# "add all files that haven't been added yet" or "add all files that have been modified"
# or "do an equivalent of svn-info.".  If you use this a lot, it is recommended that you do something like 
#   "alias gh='githelper' in your ~/.bash_profile"
#
# For example:
#   githelper info
#   githelper show untracked 
#   githelper add untracked 
#   githelper show modified 
#   githelper add modified
#   githelper show both
#   githelper add both
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
    def initialize
      @version = '0.0.1beta'
    end
    def run argv
      if (0==ARGV.size || ['--help','-h'].include?(ARGV[0]))        
        ARGV[0] = 'help'
      elsif (['-v','--version'].include?(ARGV[0]))
        ARGV[0] = 'version'
      end      
      parser = GorillaGrammar::Grammar.new({
        :verbs => {
          ['show', /^(added|modified|untracked|all)$/] => {:names=>{1=>:which}},
          ['add',  /^(added|modified|untracked|all)$/] => {:names=>{1=>:which},
            :modifiers => {
              ['as','dry','run'] => {},  # @todo waiting for full on test suite and separate library
              ['dry'] =>            {}              
            }                       
          },
          ['info'] => {},
          ['help'] => {},
          ['version'] => {}
       }
      })
      begin
        parse = parser.parse(ARGV) # throws
      rescue GorillaGrammar::ParseFailure => e
        puts e.message
      else
        send('execute_'+parse.as_key.to_s, parse.captures)
      end
    end # def run

    def execute_help args
      puts <<-END.gsub(/^ {6}/, '')
      Helpful little additions to git.
      usage: #{program_name} COMMAND [ARGS]
      commands:
         help                              Show this screen
         version                           Show version number of this script
         info                              Similar to svn info (Thanks Duane Johnson!)
         add  {added|modified|untracked|all} [[as] dry [run]]
                                            Adds all files of that kind
         show {added|modified|untracked|all} List the filenames that match the status.
                                          'all' should be equivalent
                                           output of "git --status".
      END
    end

    def execute_version args
      puts %{#{program_name} version #{@version}}
    end
                           
    def parse_status
      str = `git status`                                        
      re = %r< 
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
      raise Exception.new("regexp failure!") unless (matches = re.match str)  
      caps = matches.captures       
      ret = {
        :added     =>  caps[0] ? caps[0].scan(/^\#\t(?:new file|modified): +(.*)$\n/).flatten : [],
        :modified  =>  caps[1] ? caps[1].scan(/^\#\tmodified: +(.*)$\n/).flatten : [],
        :untracked =>  caps[2] ? caps[2].scan(/^\#\t(.*)$\n/).flatten            : []
      }
      require 'pp'
      pp ret
      exit
      ret
    end
    
    def execute_show_which(args)     
      puts get_file_list_for_add(args) * "\n"
    end
                      
    def get_file_list_for_add(args)
      which = args[:which][0].to_sym
      tree = parse_status
      if :all == which
        list = tree.values.flatten
      else
        list = tree[which]
      end
      list.sort!.uniq!
      list
    end
    
    def execute_add_which(args)
      list = get_file_list_for_add(args)
      is_dry = args[:as_dry_run] || args[:dry]
      list.each do |filename|
        s = "git add #{filename}"
        puts s
        `#{s}` unless is_dry
      end
      print "done "; (print "(with dry run)" if is_dry); print ".\n"
    end
    
    # This is a port of Duane Johnson's shell script (duane D0T johnson AT gmail D0T com, License: MIT): 
    # http://blog.inquirylabs.com/2008/06/12/git-info-kinda-like-svn-info/
    # Based on discussion at http://kerneltrap.org/mailarchive/git/2007/11/12/406496
    def execute_info args
      # Find base of git directory
      until Dir.glob('.git').length > 0 do
        if '/'==Dir.pwd   
          puts "can't find .git directory this or any parent folder!"
          exit
        end
        Dir.chdir('..')
      end

      puts "(in "+Dir.pwd+')'

      # Show various information about this git directory
      puts "== Remote URL: "
      puts `git remote -v`

      puts "== Remote Branches: "
      puts `git branch -r`

      puts "== Local Branches:"
      puts `git branch`
      puts "\n"

      puts "== Configuration (.git/config)"
      File.open('.git/config'){|fh| puts fh.read }
      puts "\n"

      puts "== Most Recent Commit"
      puts `git log --max-count=1`
      puts "\n"

      puts "Type 'git log' for more commits, or 'git show' for full commit details."
      
    end
   
    def program_name
      File.basename($PROGRAM_NAME)        
    end
  end # class GitHelper
end # module Hipe


module Hipe
  
  # if this module proves useful it will be moved out of here! 
  module GorillaGrammar
                                              
    class UsageFailure < Exception; end    
    class AmbiguousGrammarUsageFailure < UsageFailure; end
                            
    class ParseFailure < Exception; end  
    class UnexpectedEndOfInput < ParseFailure; end
    class UnexpectedInput < ParseFailure; end
          
    module Terminal
      def grammar_name
        name
      end
    end
    
    module RegexpTerminal
      include Terminal
      # if a regexp looks like /^(alpha|beta|gamma)$/ then describe it as {alpha|beta|gamma}
      def describe
        s = to_s
        if (m = %r{\(\?-mix:\^\(([^\)]+)\)\$\)}.match(s))
          %<{#{m[1]}}>
        else
          s
        end
      end
      
      def matches token
        if (md = self.match(token))
          md.captures
        else
          nil
        end
      end
      
      attr_accessor :name
      def name
        @name.to_s
      end
      
      def grammar_name
        describe
      end
      
    end
    
    module StringTerminal
      include Terminal
      def describe
        self
      end
      def matches token
        self == token
      end
      def name
        self
      end
      def grammar_name
        %{"#{self}"}
      end
    end
    
    # can't define singleton / no virtual class for Symbol
    class SymbolTerminal
      include Terminal
      def initialize(symbol)
        @internal = symbol
      end
      def describe
        @internal.inspect
      end
      def matches token
        token
      end
      def inspect
        @internal.inspect
      end
      def name
        @internal.to_s
      end
    end
    
    class Phrase
      def initialize phrase, extra
        @phrase = phrase
        @data = (extra==1 || extra==true) ? {} : extra
        @data[:grammar_index] ||= 0 #*:note2.
        @data[:i1] ||= 0    #*:note2.
        @modifiers_data = @data.delete(:modifiers) # we construct objects from it late
        @modifiers = nil
        (0..@phrase.size-1).each do |index|
          terminal = @phrase[index]
          case terminal
            when Regexp then terminal.extend RegexpTerminal; terminal.name = @data[:names][index]
            when String then terminal.extend StringTerminal
            when Symbol then @phrase[index] = SymbolTerminal.new(terminal)
            else               
              raise UsageFailure.new("invalid type for terminal: "+terminal.class.to_s)
          end
        end
      end
      
      attr_accessor :phrase
                            
      def as_key
        capture_names.map{|x|x.to_s}.join('_').to_sym      
      end
      
      def modifiers
        if @modifiers
          @modifiers
        else
          @modifiers_data = {} if @modifiers_data.nil? 
          @modifiers = Array.new(@modifiers_data.size)
          i = -1
          @modifiers_data.each do |key, mod_data|
            @modifiers[i+=1] = Phrase.new(key, mod_data)
          end
          @modifiers_data = nil
          @modifiers          
        end
      end

      def self.clone nt
        # 2009-22-16 04:38 raggi: hipe: maybe you want to look at marshal_dump and marshal_load callbacks
        Marshal.load(Marshal.dump(nt))
      end
      
      def expecting
        ret = []
        if @data[:grammar_index] <= (@phrase.size-1)
          ret << @phrase[@data[:grammar_index]]
        end
        modifiers.each do |modifier|
          ret |= modifier.expecting
        end
        ret
      end      
      
      def self.describe_expecting(nt_list)
        items = []
        nt_list.each do |nt|
          items |= nt.expecting
        end
        conjunctive_list(items.map{|x|x.grammar_name})
      end
      
      def self.conjunctive_list items
        if (items.size == 0)
          s = 'nothing'
        else
          s = items.pop
          if items.size > 0
            s = items.pop + ' or ' + s
            if items.size > 0
              s = (items * ', ') +', '+ s
            end
          end
        end
        s
      end
            
      def matched?
        @data[:matched]
      end
      
      def [](i)
        @data[i]
      end
      
      def []=(i,x)
        @data[i] = x
      end
            
      def capture_names
        @phrase.map{|x| x.name.to_sym} 
      end
      
      def captures
        use_this = []
        capture_names.each_with_index { |name, index| use_this << name; use_this << @data[:matches][index] }
        Hash[*use_this]
      end
      
      def describe_accepting_state
        terminal = @phrase[@data[:grammar_index]]
        terminal.describe        
      end
      
      def matches(token)
        @phrase[@data[:grammar_index]].matches(token)
      end
    end # class Phrase
  
    class GorillaParseTree
      def initialize verb, modifiers
        @verb = verb
        @modifiers = modifiers
      end
      
      attr_reader :verb, :modifiers
            
      def as_key
        @verb.as_key
      end  
      
      def captures
        #ret = {}
        #ret[@verb.as_key] = @verb.captures
        ret = @verb.captures
        @modifiers.each do |mod|
          ret[mod.as_key] = mod.captures
        end
        ret
      end
      
    end # class
    

     # for now a gorilla grammar is the highest level of syntactic structure - a list of verb phrase grammars
     # of which one will be determined to parse the input
     class Grammar

       def initialize grammar_data
         raise UsageFailure("bad signature for grammar data") if [:verbs] != grammar_data.keys
         @verbs = Array.new(grammar_data[:verbs].size)
         i = -1;
         grammar_data[:verbs].each do |terminal_list, extra|
           @verbs[i+=1] = Phrase.new(terminal_list,extra)
         end
         @debug_level = 0
       end # def initialize

       def parse input_list
         verb_non_terminal = parse_find_non_terminals_from_list(@verbs,input_list,:get_longest)
         shrinkme = input_list.clone
         nillify shrinkme, verb_non_terminal[:i1]..verb_non_terminal[:i2] 
         shrinkme.compact! #*:note1. 
         modifier_nts = parse_find_non_terminals_from_list(verb_non_terminal.modifiers,shrinkme,:return_all)
         modifier_nts.each do |match|
           nillify shrinkme, match[:i1]..match[:i2]
         end
         shrinkme.compact!
         if (0<shrinkme.size)
           raise ParseFailure.new(%{I can't make sense of #{shrinkme.inspect} -- I wasn't expecting any more input.})
         end
         GorillaParseTree.new(verb_non_terminal, modifier_nts)
       end

       def nillify from_array, range
         range.each { |x| from_array[x] = nil }
       end

       def debug(level,puts=false,&block)
         return if (@debug_level < level)
         if puts
           puts yield
         else 
           print yield
         end
       end

       def debugs(level,&block)
         return debug(level, true, &block)
       end

       def parse_find_non_terminals_from_list(nt_list,input_list,on_ambiguity)
         begin
           prev_possibilites = nt_list # for reporting on parse failures
           nt_list = parse_eliminate_possibilities(nt_list, input_list)
           if (nt_list.size == 0 && :return_all != on_ambiguity)
             i1 = prev_possibilites[0][:i2];  # index of the next token to look at in input
             if ( !(i1.nil?) && i1 > input_list.size-1 )
               raise UnexpectedEndOfInput.new("Unexpected end of input.  Expecting "+
                 Phrase.describe_expecting(prev_possibilites)
               )
             else      
               token = input_list[i1.nil? ? 0 : i1]
               raise UnexpectedInput.new(%{Unexpected word "#{token}". Expecting }+
                 Phrase.describe_expecting(prev_possibilites)
               )               
             end
           elsif (nt_list.find_all{|nt| nt.matched? }.size == nt_list.size)
             if (nt_list.size == 1 ) 
               match = nt_list[0]
               break;
             else
               case on_ambiguity
                 when :get_longest
                   lengths = nt_list.map { |x| x.phrase.length }
                   max = lengths.max
                   if (lengths.find_all{|x| x==max}.size > 1)
                     raise AmbiguousGrammarUsageFailure.new(
                       "Ambiguous grammar and can't find longest match! There is more than one with same length!"
                     )
                   else
                     index = lengths.find_index(max)
                     match = nt_list[index]
                     break
                   end
                when :return_all
                  match = nt_list # careful
                  break
                when :fail
                  raise AmbiguousGrammarUsageFailure.new("Ambiguous grammar!")
                else
                  raise UsageFailure.new(%{invalid "on_ambiguity" value "#{on_ambiguity.inspect}"})
               end
             end
           else # we have at least one ongoing possibility that isn't done
             #ppp :poss, nt_list
           end
         end while true
         if (:return_all==on_ambiguity && !match.instance_of?(Array))  # ick
           [match]
         else 
           match
         end
       end # def parse

       # 'pz' stands for "possibilities" -- it started to hurt my fingers and eyes writing and reading it                         
       def parse_eliminate_possibilities(pz, input_list)
         result_pz = []      
         pz.each do |nt|
           if nt.matched? then result_pz << Phrase.clone(nt); next; end
           debugs(1){ %{****checking possibility of this phrase: #{nt.phrase.inspect}} }
           input_list_indexes = nt[:i2] ? [nt[:i2]] : (0..input_list.size-1).to_a
           input_list_indexes.each do |input_index|
             token = input_list[input_index]
             debug(1){%{checking token #{token.inspect} against terminal symbol "#{nt.describe_accepting_state}"}}
             if (!(match_data = nt.matches(token)))
               debug(1){" and not adding\n"}
             else
               debug(1){" and adding \n"}
               nt2 = Phrase.clone(nt)
               nt2[:matches] ||= []
               nt2[:matches] << match_data          
               nt2[:i1] = input_index if nt2[:i1] == false
               if nt2[:grammar_index] == (nt2.phrase.size-1)
                 nt2[:matched] = true
                 nt2[:i2] = nt2[:i1] unless nt2[:i2]
               else
                 nt2[:i2] = (nt2[:i2]) ? (nt2[:i2]+1) : (nt2[:i1]+1)
               end
               nt2[:grammar_index] += 1
               result_pz << nt2
             end
           end
         end
         result_pz
       end # def parse_eliminate_possibilities
     end # class Grammar
   end # module GorillaGrammar
 end # module Hipe
 #*note1: if we wanted to be really anal we would parse the first half and 
 #*note2: this is showing straing where it would be good to have a dedicated tree class
 # second half separately to avoid interference but it seems like overkill at this early point.
 # and almost never a big deal unless really ambiguous G's
    
                       
if File.basename($PROGRAM_NAME) == File.basename(__FILE__) && ARGV[0] != 'gorillatest'

  Hipe::GitHelper::new.run(ARGV)
end # if running this file



###### start temporary echo debugging ######

require 'pp'

def p symbol, object=nil, die=nil
  unless (symbol.instance_of?(Symbol) || symbol.instance_of?(String))
    die = object
    object = symbol
    symbol = 'YOUR VALUE'
  end
  puts spp(symbol, object)
  if die
    exit
  end
end

# PrettyPrint.pp() that returns a string instead (like puts) of print to standard out, 
# like sprintf() is to printf().  prints info about where it was called from.
def spp label, object
  # go backwards up the call stack, skipping caller methods we don't care about (careful!)
  # this is intended to show us the last interesting place from which this was called.
  i = line = methname = nil
  caller.each_with_index do |line,index|
    matches = /`([^']+)'$/.match(line)
    break if (matches.nil?) # almost always the last line of the stack -- the calling file name
    matched = /(?:\b|_)(?:log|p|spp)(?:\b|_)/ =~ matches[1]
    break unless matched
  end
  m = /^(.+):(\d+)(?::in `(.+)')?$/.match line
  raise CliException.new(%{oops failed to make sense of "#{line}"}) unless m
  path,line,meth = m[1],m[2],m[3]
  file = File.basename(path)
  PP.pp object, obj_buff=''
  
  # location = "(at #{file}:#{meth}:#{line})"
  location ="(at #{file}:#{line})"        
  if (location == @last_location)
    location = nil
  else 
    @last_location = location
  end
  
  buff = '';
  buff << label.to_s + ': ' if label
  buff << location if location
  buff << "\n" if (/\n/ =~ obj_buff)
  buff << obj_buff
  buff
end

###### end temporary echo debugging ######


# in lieu of proper tests -- this is for GorillaGrammar only
# if File.basename($PROGRAM_NAME) == File.basename(__FILE__) && ARGV[0] == 'gorillatest'
#   grammar = Hipe::GorillaGrammar::Grammar.new({
#     :verbs => {
#      ['make','this'] => {
#        :modifiers => {
#          ['with','that'] => true, 
#          ['with','the', 'other'] => true
#        } 
#      },
#      ['make','that'] => {
#        :modifiers => {
#          ['now'] => true
#        }
#      },
#      ['say', 'this', 'word', :thiz] => {
#        :modifiers => {
#          ['to', :who] => true,
#          ['really', 'loudly'] => true         
#        }
#      },
#      ['say', 'something'] => {
#        :modifiers => { ['xxxx']=>true }
#      },
#      ['run'] => {
#      
#      }
#    }
#  });
# 
#   puts "\n\n\n\n"
#   
#   parse_tree = grammar.parse(['to','jim','say','this','word','englefish','really','loudly'])
#   
#   p :parse_tree, parse_tree          
# 
#   #['do','this'] => {
#   #  :modifiers => {
#   #    ['with','that'] => {}
#   #  }
#   #}
#   # ['tell', /^(.+)$/, :subject, 'said', :something] => {
#   #   :names => {1=>:who},
#   #   :modifiers => {['rather','loudly']=>1}
#   # }
#   # ['alpha','beta','gamma'] => {} ,
#   # ['lambda','ringo','star'] => {},
#   # ['alpha','beta'] => {}
#   
#       
#                  
#       ######################### Testing Methods #############################
#       def execute_do_this args
#         puts "we are doing this with: "+args.captures.inspect
#         pp args
#       end
#       def execute_tell_who_subject_said_something(tree)
#         caps = tree.verb.captures
#         tree.modifiers.each { |mod| caps.merge! mod.captures }
#         puts %{hey #{caps[:who][0]}, #{caps[:subject]} said "#{caps[:something]}"}
#       end
#       ######################### End Testing Methods ##########################
#       
#   
#   
#   
# end
# 
# pz.to_enum.with_index.select{|e,i| e > 5 }.map{|e,i| i } from manveru sunday 18:08    
# we considered using Diff::LCS.LCS for this but -- we need contiguous matches