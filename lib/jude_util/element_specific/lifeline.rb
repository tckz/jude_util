
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# ライフライン
		class	TreatLifeline < JudeElement
			def	initialize
				super("lifeline")
			end

			def	doit(el, e, index)
				if e.base 
					el["base"] = self.make_fullname(e.base)
					el["ref_base"] = e.base.getId
				end

				el["is_destroyed"] = e.isDestroyed.to_s

				# 相互作用フラグメント
				self.process_childs("fragments", el, e, e.fragments)
			end
		end

	end

end


# vi: ts=2 sw=2

