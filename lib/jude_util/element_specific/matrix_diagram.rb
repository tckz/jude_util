
module	JudeUtil

	# JUDE要素固有処理クラス群
	# クラス名は/^Treat/であること
	module	ElementSpecific

		# マトリックス：CRUD図
		class	TreatMatrixDiagram < JudeElement
			def	initialize
				super("matrix_diagram")
			end

			def	doit(el, e, index)
				self.process_childs("show_row_headers", el, e, e.showRowHeaders)
				self.process_childs("show_column_headers", el, e, e.showColumnHeaders)

				el_cvs = el.doc.createElement("cell_values")
				el << el_cvs
				(0..e.rowHeaders.length-1).each {|y|
					(0..e.columnHeaders.length-1).each{ |x|
						cv = e.getShowValueCell(y, x)
						if cv 
							el_cv = el.doc.createElement("cell")
							el_cv["row"] = y.to_s
							el_cv["col"] = x.to_s
							el_cv["read"] = cv.isRead.to_s
							el_cv["create"] = cv.isCreate.to_s
							el_cv["update"] = cv.isUpdate.to_s
							el_cv["delete"] = cv.isDelete.to_s
							el_cv << cv.value.to_s
							el_cvs << el_cv
						end
					}
				}
			end
		end

	end

end


# vi: ts=2 sw=2

