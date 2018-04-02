
class Config {

	static var CFG : {
		var ocamlVersion : String;
		var cygwinTools : Array<String>;
		var mingwLibs : Array<String>;
		var opamLibs : Array<String>;
	} = loadConfig();

	static function loadConfig() {
		var content = try sys.io.File.getContent("haxe/config.json") catch( e : Dynamic ) sys.io.File.getContent("config.json");
		return haxe.Json.parse(content);
	}

	function new() {
	}

	function log( msg : String ) {
		Sys.println(msg);
	}

	function command(cmd,args:Array<String>) {
		log("> "+cmd+" "+args.join(" "));
		var r = Sys.command(cmd,args);
		if( r != 0 ) throw "Command exit with code "+r;
	}

	function wide2utf( s : String ) {
		var b = new haxe.Utf8();
		for( i in 0...s.length>>1 ) {
			var c = s.charCodeAt(i<<1) | (s.charCodeAt((i<<1) + 1) << 8);
			b.addChar(c);
		}
		return b.toString();
	}

	function utf2wide( s : String ) {
		var buf = new StringBuf();
		haxe.Utf8.iter(s,function(c) {
			buf.addChar(c&0xFF);
			buf.addChar(c>>8);
		});
		return buf.toString();
	}

	function utf2hex( s : String ) {
		var hex = "";
		haxe.Utf8.iter(s,function(c) {
			hex += ","+StringTools.hex(c&0xFF,2)+","+StringTools.hex(c>>8,2);
		});
		return hex.substr(1);
	}

	function hex2utf( hex : String ) {
		var str = new haxe.Utf8();
		var hex = hex.split(",");
		for( i in 0...hex.length>>1 ) {
			var c = Std.parseInt("0x"+hex[i<<1]) | (Std.parseInt("0x"+hex[(i<<1)+1]) << 8);
			if( c == 0 ) break;
			str.addChar(c);
		}
		return str.toString();
	}

	function setup() {

		var dir = Sys.getEnv("TMP");
		if( dir == null )
			dir = ".";
		var temp = dir + "\\env.txt";

		// looking for CYGWIN
		var p = new sys.io.Process("where.exe",["cygpath.exe"]);
		var cygwinPath = null;
		if( p.exitCode() == 0 ) {
			cygwinPath = StringTools.trim(p.stdout.readAll().toString()).substr(0,-15);
			log("Cygwin found in "+cygwinPath);

			for( f in CFG.cygwinTools )
				if( !sys.FileSystem.exists(cygwinPath+"/bin/"+f+".exe") )
					throw "Missing required cygwin tool: "+f;

			var mingw = cygwinPath+"/usr/i686-w64-mingw32/sys-root/mingw";
			for( lib in CFG.mingwLibs )
				if( !sys.FileSystem.exists(mingw+"/bin/"+lib+".dll") )
					throw "Missing mingw library: "+lib+" (in "+mingw+"/bin)";

		} else {
			log("Cygwin not found");
		}

		// get environment
		log("Querying environment...");
		command("regedit",["/E",temp,"HKEY_CURRENT_USER\\Environment"]);
		var data = try sys.io.File.getContent(temp);
		sys.FileSystem.deleteFile(temp);
		var data = wide2utf(data).split("\r\n");

		// inject required env in PATH
		var foundPath = "";
		for( i in 0...data.length ) {
			var line = data[i];
			if( line.substr(0,7).toUpperCase() == '"PATH"=' ) {
				foundPath = line.substr(7,line.length-7);
				if( StringTools.startsWith(foundPath,"\"") )
					foundPath = foundPath.substr(1);
				if( StringTools.endsWith(foundPath,"\"") )
					foundPath = foundPath.substr(0,foundPath.length-1);
				var i = i + 1;
				while( foundPath.charAt(foundPath.length - 1) == "\\" ) {
					foundPath = foundPath.substr(0,foundPath.length - 1);
					foundPath += StringTools.trim(data[i++]);
				}
				if( StringTools.startsWith(foundPath,"hex(2):") )
					foundPath = hex2utf(foundPath.substr(7));
				break;
			}
		}
		if( foundPath.toUpperCase().indexOf("%OCAMHAXE%") < 0 ) {
			if( StringTools.endsWith(foundPath,";") )
				foundPath += "%OCAMHAXE%;";
			else
				foundPath += ";%OCAMHAXE%";
		}
			
		// apply environment changes
		// using regedit is the best to preserve PATH with special chars
		log("Updating Environment...");
		var regConf = sys.io.File.getContent("haxe/reg.conf");
		regConf = regConf.split("$newPath").join(utf2hex(foundPath));

		var f = sys.io.File.write(temp);
		f.writeString("\xFF\xFE"+utf2wide(regConf));
		f.close();
		command("regedit",["/S",temp]);

		// using setx for others so it trigger WM_SETTINGCHANGE
		var cwd = Sys.getCwd();
		var paths = [cwd+"bin"];
		var ocamlPath = null;

		// look for ocaml in opam
		for( f in sys.FileSystem.readDirectory(".opam") )
			if( f.substr(0,2) == "4." )  {
				ocamlPath = cwd+".opam/"+f;
				paths.push(ocamlPath+"/bin");
				break;
			}

		if( ocamlPath == null )
			throw "No ocaml found in .opam!";

		command("setx",["OCAMLLIB",ocamlPath+"/lib/ocaml"]);
		command("setx",["OCAMLFIND_CONF",ocamlPath+"/lib/findlib.conf"]);
		command("setx", ["OPAMROOT", cwd+".opam"]);

		// add our cygwin/MinGW local install
		if( cygwinPath == null )
			paths.push(cwd+"mingw/bin");

		command("setx", ["OCAMHAXE", paths.join(";")]);


		// setup ld.conf
		var f = sys.io.File.getContent("haxe/ld.conf");
		f = f.split("$ocamlPath").join(ocamlPath);
		sys.io.File.saveContent(ocamlPath + "/lib/ocaml/ld.conf", f);

		// setup ocamlfind
		var f = sys.io.File.getContent("haxe/findlib.conf");
		f = f.split("$ocamlPath").join(ocamlPath.split("\\").join("\\\\"));
		sys.io.File.saveContent(ocamlPath + "/lib/findlib.conf", f);
	}

	function run() {
		try {
			setup();
			log("Setup successful!");
		} catch( e : String ) {
			log("**ERROR** "+e);
		} catch( e : Dynamic ) {
			log("**ERROR** " + e + haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
		}
		log("Press enter to exit");
		Sys.stdin().readLine();
	}

	static function main() {
		new Config().run();
	}
}