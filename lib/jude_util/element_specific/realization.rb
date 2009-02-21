
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# 実現
		class	TreatRealization < JudeElement
			def	initialize
				super("realization")
			end

			def	doit(el, e, index)
				if e.client
					el["client"] = self.make_fullname(e.client)
				end

				if e.supplier
					el["supplier"] = self.make_fullname(e.supplier)
				end
			end
		end

	end

end


# vi: ts=2 sw=2

