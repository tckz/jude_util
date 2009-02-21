
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# 属性
		class	TreatAttribute < JudeElement
			def	initialize
				super("attribute")
			end

			def	tag(e)
				if e.association
					return	"attribute_assoc"
				end
				return	@tag
			end

			def	doit(el, e, index)
				el["type"] = self.make_fullname(e.type)
				el["ref_type"] = e.type.getId
				el["initial_value"] = e.initialValue

				# refs #7 可視性
				self.set_visibility(e, el)
				self.traverse_into(el, e.association)
			end
		end

	end

end


# vi: ts=2 sw=2

