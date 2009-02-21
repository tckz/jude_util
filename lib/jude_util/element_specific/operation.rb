
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# 操作
		class	TreatOperation < JudeElement
			def	initialize
				super("operation")
			end

			def	doit(el, e, index)
				rettype = e.returnType
				if rettype
					el["return_type"] = self.make_fullname(rettype)
					el["ref_return_type"] = rettype.getId
				end

				# refs #7 可視性
				self.set_visibility(e, el)
				self.process_childs("parameters", el, e, e.parameters)
			end
		end

	end

end


# vi: ts=2 sw=2

