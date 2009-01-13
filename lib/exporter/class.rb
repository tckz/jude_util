
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# クラス
		class	TreatClass < JudeElement
			def	initialize
				super("class")
			end
			def	doit(el, e, index)
				self.process_childs("nested_classes", el, e, e.getNestedClasses)
			end
		end

	end

end


# vi: ts=2 sw=2

