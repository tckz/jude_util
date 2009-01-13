#!/usr/bin/ruby

# = actor_list.rb: retrieve <<actor>> classes from the xml
#
# Author:: tckz <at.tckz@gmail.com>
#   http://passing.breeze.cc/

$KCODE='u'

require 'optparse'
require 'ostruct'
require 'pp'

$:.unshift(File.dirname(__FILE__))
require 'lib/jude_util'

module	JudeUtil

	class	ActorList

		include	JudeUtil

		def	initialize(root, options)
			@root = root
			@options = options
		end

		def	out_list(io)
			self.actor_list.each { |cols|
				self.esc_out(cols, io)
			}
		end

		# アクターリスト
		def	actor_list()

			lines = []

			acs = self.select_target(@root, "//class[./stereotypes/stereotype[text()='actor']]", @options).find_all { |e|
				!(self.find_annotations(e, "@key='@noest'").size > 0)
			}

			parent_pkgs = {}

			acs.each { |ac|

				name = self.get_name(ac)
				fullname = self.get_fullname(ac)
				namespace = self.get_namespace(ac)

				if namespace != "" && !parent_pkgs[namespace]
					pkg = self.get_parent(ac)
					if !@options.wo_pkg
						lines.push(
							[
								namespace, 
								"", namespace, namespace, 
								# APIの仕様でパッケージ配下の図中のコメントが紐づくので「定義」のみに絞る
								self.make_desc(pkg, "\n--\n", true), 
								"",
							]
						)
					end
					parent_pkgs[namespace] = pkg
				end

				desc = self.make_desc(ac, "\n--\n", @options.definition_only) 

				# ユースケースポイント用の「係数」
				factor = nil
				el_an = self.find_annotations(ac, "@key='@factor'").first
				if el_an
					factor = el_an.child.to_s.strip
				end

				lines.push(
					[
						"", 
						name, namespace, fullname, 
						desc, 
						factor
					]
				)
			}

			lines
		end

		#
		# argv::
		#   ARGV
		def	self.main(argv)

			options = OpenStruct.new
			options.encode = "utf-8"
			options.since = nil
			options.fn_out = nil
			options.use_alias1 = nil
			options.fullname = nil
			options.definition_only = nil
			options.wo_pkg = false

			# オプション
			OptionParser.new { |opt|
				opt.banner = "usage: #{File.basename($0)} [options] [in.xml]"
				opt.separator ""
				opt.separator " o retrieve actor-list"
				opt.separator " o use STDIN instead of file if in.xml was ommited."
				opt.separator ""
				opt.separator "Options:"

				opt.on("--definition-only", "the desc looked up from only definition") do |v|
					options.definition_only = true
				end

				opt.on("--without-package", "exclude package info") do |v|
					options.wo_pkg = true
				end

				opt.on("-e", "--encoding=ENCODING-NAME", "default: #{options.encode}") do |v|
					options.encode = v
				end
			
				opt.on("-f", "--fullname=REGEX", "criteria for fullname") do |v|
					options.fullname = v
				end

				opt.on("-o", "--out=FILENAME", "filename for output") do |v|
					options.fn_out = v
				end

				opt.on("-s", "--since=REGEX", "criteria for @since") do |v|
					options.since = v
				end

				opt.on("-a", "--use-alias1", "use alias1 to identifiers") do |v|
					options.use_alias1 = true
				end

				begin
					opt.parse!(argv)
				rescue ArgumentError, OptionParser::ParseError => e
					STDERR.puts opt.to_s
					STDERR.puts ""
					STDERR.puts "#{e.message}"
					return	1
				end
			}

			fn_in = argv[0]

			doc = JudeUtil::XML::build_document(fn_in)

			fp_out = nil
			begin
				if options.fn_out
					io_out = fp_out = File.new(options.fn_out, "w")
				else
					io_out = STDOUT
				end
				io_out.extend(TextConverter).from_to("utf-8", options.encode)

				ul = JudeUtil::ActorList.new(doc.root, options)

				ul.out_list(io_out)
			ensure
				if fp_out
					fp_out.close
				end
			end

			0
		end
	end
end


if $0 == __FILE__
	include	JudeUtil
	include	JudeUtil::XML

	Version = JudeUtil::Version
	exit	JudeUtil::ActorList::main(ARGV)
end


# vi: ts=2 sw=2

