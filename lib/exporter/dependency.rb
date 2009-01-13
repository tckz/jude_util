
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# 依存
		class	TreatDependency < JudeElement
			def	initialize
				super("dependency")
			end

			def	doit(el, e, index)
				el["client"] = self.make_fullname(e.client)
				el["supplier"] = self.make_fullname(e.supplier)
			end
		end


	end

end


# vi: ts=2 sw=2

