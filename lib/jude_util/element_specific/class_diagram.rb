
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# クラス図
		# クラス図中に使用されているモノのリストを取得したいが・・
		class	TreatClassDiagram < JudeElement
			def	initialize
				super("class_diagram")
			end

			#def	doit(el, e, index)
				#klass = e.java_class
				#STDERR.puts klass
				#klass.java_instance_methods.each { |m|
					#STDERR.puts "\t#{m.name}"
				#}
				#STDERR.puts e.class
				#e.text.each { |t|
					#STDERR.puts t
				#}
			#end
		end


	end

end


# vi: ts=2 sw=2

