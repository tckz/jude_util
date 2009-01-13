
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# メッセージ
		class	TreatMessage < JudeElement
			def	initialize
				super("message")
			end

			def	doit(el, e, index)
				# sourceもtargetもILifelineを指す様子
				if e.target 
					el["ref_target"] = e.target.getId
				end
				if e.source
					el["ref_source"] = e.source.getId
				end

				# TODO: 5.4 ライフラインに「停止」があるとき、これも内部的にはメッセージ扱いらしく、キャスト例外で死ぬ
				# ので、一旦出力ナシに
				#if e.index
				#	el["index"] = e.index.to_s
				#end

				if e.return_value
					el["return_value"] = e.return_value.to_s
				end

				if e.operation 
					el["operation"] = self.make_fullname(e.operation)
					el["ref_operation"] = e.operation.getId
				end
				if e.argument != ""
					el["argument"] = e.argument
				end

				if e.activator
					el["ref_activator"] = e.activator.getId
				end

				if e.predecessor
					el["ref_predecessor"] = e.predecessor.getId
				end

				if e.successor
					el["ref_successor"] = e.successor.getId
				end

				el["is_asynchronous"] = e.isAsynchronous.to_s
				el["is_return_message"] = e.isReturnMessage.to_s
				el["is_synchronous"] = e.isSynchronous.to_s
			end
		end

	end

end


# vi: ts=2 sw=2

