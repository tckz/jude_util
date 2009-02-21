
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# シーケンス図
		class	TreatSequenceDiagram < JudeElement
			def	initialize
				super("sequence_diagram")
			end

			def	doit(el, e, index)
				interaction = e.interaction
				if !interaction
					return
				end
				el["argument"] = interaction.argument.to_s
				self.process_childs("lifelines", el, e, interaction.lifelines)
				self.process_childs("gates", el, e, interaction.gates)
				self.process_childs("messages", el, e, interaction.messages)
			end
		end

	end

end


# vi: ts=2 sw=2

