
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific
		# 関連
		class	TreatAssociation < JudeElement
			def	initialize
				super("association")
			end

			def	doit(el, e, index)
				# IAssociationの属性=関連端
				e.attributes.each { |p|
					el_rel = el.doc.createElement("kanrentan")
					el << el_rel
					self.add_name_attr(p, el_rel)
					el_rel["is_aggreate"] = p.isAggregate.to_s
					el_rel["is_composite"] = p.isComposite.to_s
					el_rel["is_enabled"] = p.isEnable.to_s

					# 多重度
					muls = p.multiplicity
					if muls.size > 0 
						el_muls = el.doc.createElement("multiplicities")
						el_rel << el_muls
						muls.each { |mul|
							el_mul = el.doc.createElement("multiplicity")
							el_muls << el_mul
							el_mul["lower"] = mul.lower.to_s
							el_mul["upper"] = mul.upper.to_s
							t = self.multiplicity_text(mul.lower, mul.upper)
							if t != ""
								el_mul << t
							end
						}
					end
				}
			end

			# 多重度の「0..1」「0..*」な文字列を返す
			def	multiplicity_text(lower, upper)
				t = ''

				doit = Proc.new { |v|
					r = ""
					if v == 1
						r = "1"
					elsif v == 0
						r = "0"
					elsif v == -1
						r = "*"
					end

					r
				}

				ret = ""
				lo_text = doit.call(lower)
				up_text = doit.call(upper)
				if lo_text != "" and up_text != ""
					if lo_text == up_text 
						ret = lo_text
					else
						ret = "#{lo_text}..#{up_text}"
					end
				end

				ret
			end
		end

	end

end


# vi: ts=2 sw=2

