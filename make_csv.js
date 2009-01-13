/**
 * テーブル属性一覧的なシートをERモデルインポート用書式のcsvで書き出す。
 *
 * シートごとに別ファイルとして出力
 *
 * jrubyスクリプト側で日本語ファイル名を上手く処理できてないので、
 * 出力ファイル名配慮要
 *
 * ブック間でシート名がかぶると上書きされちゃう
 *
 * cscript make_csv.js [options] 入力xls...
 *
 * options:
 *   /out:出力ディレクトリ(default: .)
 *   /fs:出力CSVのフィールドセパレータ(default: ,)
 */

if(!WScript.FullName.match(/cscript\.exe$/i))
{
	WScript.echo("run me under cscript.exe");
	WScript.Quit();
}


function MakeCSV()
{
	this.initialize.apply(this, arguments);
}

MakeCSV.prototype = {
	/**
	 * 初期化
	 */
	initialize: function() 
	{
		this.fso = WScript.CreateObject("Scripting.FileSystemObject");
	},

	/**
	 * CSV一行分出力
	 *
	 * @param	st	出力先テキストストリーム
	 * @param	rec	一行分の情報を詰めた配列
	 * @param	fs	出力のフィールドセパレータ
	 * @param	is_header	ヘッダ行出力かどうかを示す真偽値
	 */
	out_rec: function(st, rec, fs, is_header)
	{
		var items = [];
		for(var i in rec)
		{
			var v = rec[i];
			if(v == undefined)
			{
				v = "";
			}
			// 数値も文字列に
			v = v + "";
			
			// ヘッダ行マーク
			if(is_header && i == 0)
			{
				v = "#" + v;
			}
			
			// looseにエスケープなぞ
			v = v.replace(/"/g, '""');
			items.push('"' + v + "\"");
		}

		st.WriteLine(items.join(fs));
	},

	/** 
	 * エンティティ一個分出力
	 *
	 * @param	fn	出力ファイル名
	 * @param	ent	エンティティ一個分の情報を詰めたhash
	 * @param	fs	出力CSVのフィールドセパレータ
	 */
	out_csv: function(fn, ent, fs)
	{
		var	st = this.fso.OpenTextFile(fn, 2, true);
		
		try {
			// エンティティの情報
			this.out_rec(st, ["@entity", ent.logicalname, ent.physicalname], fs, true);
			
			// ヘッダ
			// 最初の属性の持つkeyをヘッダとみなして処理
			// なので、属性のない出力は例外死
			var header = [];
			for(var k in ent.attributes[0])
			{
				header.push(k);
			}
			this.out_rec(st, header, fs, true);
			
			// 各属性
			for(var i in ent.attributes)
			{
				var attr = ent.attributes[i];
			
				var rec = [];
				for(var i in header)
				{
					rec.push(attr[header[i]]);
				}
				this.out_rec(st, rec, fs, false);
			}

		} catch(ex) {
			throw	ex;
		} finally {
			st.Close();
		}
	},
	
	/**
	 * シート一個分出力処理
	 * シートのレイアウト次第。samp1.xlsを前提としたコード
	 *
	 * @param	fn_out	出力ファイル名
	 * @param	sh		Worksheetオブジェクト
	 * @param	options	動作オプション
	 */
	do_sheet: function(fn_out, sh, options) 
	{
		var attrs = [];
		var ent = {
			logicalname: "",
			physicalname: "",
			attributes: attrs
		};
		
		// テーブルの名前
		ent.logicalname = sh.Cells(1, 2).Value;
		ent.physicalname = sh.Cells(2, 2).Value;
		
		// 各属性
		for(var row = 5; ;row++)
		{
			// 論理名がundefinedならおしまい
			if(!sh.Cells(row, 1).Value)
			{
				break;
			}
			
			var attr = {
				logicalname: 	sh.Cells(row, 1).Value,
				physicalname: 	sh.Cells(row, 2).Value,
				domain: 		sh.Cells(row, 3).Value,
				type: 			sh.Cells(row, 4).Value,
				length: 		sh.Cells(row, 5).Value,
				pk: 			sh.Cells(row, 6).Value,
				nn: 			sh.Cells(row, 7).Value,
				"default": 		sh.Cells(row, 8).Value
			};
			
			attrs.push(attr);
		}
		
		// 出力
		this.out_csv(fn_out, ent, options.fs);
	},
	
	/**
	 * xls一個分
	 * 各シートをなめる
	 * 
	 * @param	excel	エクセルアプリケーションオブジェクト
	 * @param	options	動作オプション
	 * @param	fn_xls	入力xlsファイル名
	 */
	do_xls: function(excel, options, fn_xls) 
	{
		
		if(!this.fso.FolderExists(options.out))
		{
			this.fso.CreateFolder(options.out);
		}

		var book = excel.Workbooks.Open(fn_xls, true);
		
		try {
			for(var i = 1; i <= book.Sheets.Count; i++)
			{
				var sh = book.Sheets(i);
				var name = sh.Name + ".csv";
				var fn_out = this.fso.BuildPath(options.out, name);
				this.do_sheet(fn_out, sh, options);
			}
		} catch(ex) {
			throw ex;
		} finally {
			book.Close(false);
		}

	},
	
	/**
	 * main
	 * 
	 * @param	argv	WScript.Arguments
	 */
	main: function(argv) 
	{
		// オプション
		var opt = argv.Named;
		
		var options = {
			// 出力先フォルダ
			out: ".",
			// 出力CSVのフィールドセパレータ
			fs: ","
		};
		
		if(opt.Item("fs"))
		{
			options.fs = opt.Item("fs") ;
		}
		if(opt.Item("out"))
		{
			options.out = opt.Item("out") ;
		}
		options.out = this.fso.GetAbsolutePathName(options.out);
		
		var	excel = new ActiveXObject("Excel.Application");
		
		try {
			excel.DisplayAlerts = false;

			// 引数
			var args = argv.Unnamed;
			for(var i = 0; i < args.length; i++)
			{
				var fn_xls = this.fso.GetAbsolutePathName(args(i));
				if(!this.fso.FileExists(fn_xls))
				{
					WScript.echo("*** xls not not found: " + fn_xls);
					return false;
				}
				
				this.do_xls(excel, options, fn_xls);
			}
		} catch(ex) {
			throw ex;
		} finally {
			excel.Quit();
		}
	}
};

// --------------------------------------------------------------

var	app = new MakeCSV();
app.main(WScript.Arguments);




