
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# ERスキーマ
		class	TreatERSchema < JudeElement
			def	initialize
				super("er_schema")
			end

			def	doit(el, e, index)
				self.process_childs("datatypes", el, e, e.datatypes)
				self.process_childs("domains", el, e, e.domains)
				self.process_childs("entities", el, e, e.entities)
			end
		end

	end

end


# vi: ts=2 sw=2

