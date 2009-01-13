
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# フロー
		class	TreatFlow < JudeElement
			def	initialize
				super("flow")
			end
			def	doit(el, e, index)
				el["action"] = e.action.to_s
				el["guard"] = e.guard.to_s
				if e.source
					el["ref_source"] = e.source.getId
				end
				if e.target
					el["ref_target"] = e.target.getId
				end
			end
		end

	end

end


# vi: ts=2 sw=2

