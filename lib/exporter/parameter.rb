
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# パラメータ
		class	TreatParameter < JudeElement
			def	initialize
				super("parameter")
			end

			def	doit(el, e, index)
				if e.type
					el["type"] = self.make_fullname(e.type)
					el["ref_type"] = e.type.getId
				end

				el["type_expression"] = e.getTypeExpression
				el["direction"] = e.direction
			end
		end

	end

end


# vi: ts=2 sw=2

