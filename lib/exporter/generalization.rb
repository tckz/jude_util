
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# 汎化
		class	TreatGeneralization < JudeElement
			def	initialize
				super("generalization")
			end

			def	doit(el, e, index)
				if e.superType
					el["super"] = self.make_fullname(e.superType)
				end
				if e.subType
					el["sub"] = self.make_fullname(e.subType)
				end
			end
		end

	end

end


# vi: ts=2 sw=2

