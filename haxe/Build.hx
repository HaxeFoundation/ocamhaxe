import haxe.io.Path;

class Build {

	static var CFG = @:privateAccess Config.CFG;

	var cygwinPath(default, set) : String;
	var cygwinBinPath : String;

	function set_cygwinPath(value:String) {
		this.cygwinPath = value;
		cygwinBinPath = Path.join([cygwinPath, "bin"]);
		return value;
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

	function deleteFile(path:String) {
		try sys.FileSystem.deleteFile(path) catch(e : Dynamic) {}
	}

	function makeDir(path:String) {
		try sys.FileSystem.createDirectory(path) catch(e:Dynamic) {}
	}

	function cygCommand(cmd,args:Array<String>) {
		command("bash",["-c",cmd+" "+args.join(" ")]);
	}

	var copiedFiles = new Map();

	function cygCopyFile( file : String ) {

		copiedFiles.set(file, true);
		try sys.io.File.copy(cygwinPath + "/" + file, "mingw/" + file) catch( e : Dynamic ) log("*** MISSING " + file+" in your Cygwin install ***");

		if( !StringTools.endsWith(file.toLowerCase(),".exe") && !StringTools.endsWith(file.toLowerCase(),".dll") )
			return;

		// look for dll dependencies
		var o = new sys.io.Process("dumpbin.exe",["/IMPORTS","mingw/"+file]);
		var lines = o.stdout.readAll().toString().split("\n");
		o.exitCode();
		var r = ~/^[A-Za-z0-9_-]+\.dll$/;
		for( f in lines ) {
			var f = StringTools.trim(f);
			if( !r.match(f) || copiedFiles.exists(f) ) continue;
			if( !sys.FileSystem.exists(cygwinPath+"/bin/"+f) ) continue;
			cygCopyFile("bin/"+f);
		}
	}

	function getExePath( exeFile : String ) {
		var p = new sys.io.Process("where.exe",[exeFile]);
		if( p.exitCode() != 0 )
			return null;
		var out = StringTools.trim(p.stdout.readAll().toString());
		return out.substr(0,-(exeFile.length+1));
	}

	function detectCygwin() {
		var path = getExePath("cygpath.exe");
		if( path == null ) {
			log("Cygwin not found");
			Sys.exit(1);
		}
		cygwinPath = path.substr(0,-3);
		log("Cygwin found in "+cygwinPath);
	}

	function cygCopyDir( dir : String ) {
		var baseDir = "";
		for( f in dir.split("/") ) {
			if( baseDir == "" )
				baseDir = f;
			else
				baseDir += "/"+f;
			makeDir("mingw/"+baseDir);
		}
		cygCopyRec(dir);
	}

	function cygCopyRec( dir : String ) {
		var cygDir = cygwinPath + "/" + dir;
		var files = try sys.FileSystem.readDirectory(cygDir) catch( e : Dynamic ) {
			log("*** MISSING "+dir+" in your Cygwin install ***");
			return;
		}
		for( f in files )
			if( sys.FileSystem.isDirectory(cygDir+"/"+f) ) {
				makeDir("mingw/"+dir+"/"+f);
				cygCopyRec(dir+"/"+f);
			} else
				cygCopyFile(dir+"/"+f);
	}

	function build() {

		// build minimal mingw distrib to use if the user doesn't have cygwin installed

		var bits = CFG.is64 ? 64 : 32;
		var mingw = CFG.is64 ? "x86_64-w64-mingw32" : "i686-w64-mingw32";

		detectCygwin();

		Sys.println("Preparing mingw distrib...");
		makeDir("mingw/bin");
		for( f in CFG.cygwinTools )
			cygCopyFile("bin/"+ f.split("$MINGW").join(mingw) + ".exe");
		cygCopyDir('usr/$mingw');
		cygCopyDir('lib/gcc/$mingw');
		makeDir("mingw/tmp");

		// build opam repo with packages necessary for haxe

		Sys.println("Preparing opam...");

		var opam = 'opam$bits.tar.xz';
		var ocaml = CFG.ocamlVersion + '+mingw$bits';

		if( !sys.FileSystem.exists("bin") ) {
			// install opam
			deleteFile(opam);
			command("wget",[CFG.opamUrl+opam]);
			command(Path.join([cygwinBinPath, "tar"]),["-xf",opam,"--strip-components","1"]);
			deleteFile(opam);
			deleteFile("install.sh");
		}

		// copy necessary runtime files from our local mingw to our local bin so they are added to PATH in Config
		for( lib in CFG.mingwLibs ) {
			var out = "bin/"+lib+".dll";
			if( !sys.FileSystem.exists(out) )
				sys.io.File.copy('mingw/usr/$mingw/sys-root/mingw/bin/'+lib+".dll",out);
		}

		var cwd = Sys.getCwd().split("\\").join("/");
		var opamRoot = cwd+".opam";

		// temporarily modify the env
		// setting cygwin with highest priority is necessary
		Sys.putEnv("PATH", [
			cwd+"bin",
			cygwinPath + "bin",
			opamRoot+"/"+ocaml+"/bin",
			Sys.getEnv("PATH")
		].join(";"));
		Sys.putEnv("OPAMROOT", opamRoot);
		Sys.putEnv("OCAMLLIB", opamRoot+"/"+ocaml+"/lib/ocaml");
		Sys.putEnv("OCAMLFIND_CONF", opamRoot+"/"+ocaml+"/lib/findlib.conf");

		if( !sys.FileSystem.exists(opamRoot) )
			cygCommand("opam",["init","--yes","default","https://github.com/ocaml-opam/opam-repository-mingw.git#sunset","--comp",ocaml,"--switch",ocaml]);

		cygCommand("opam",["switch",ocaml]);
		cygCommand("opam",["repo", "set-url", "fallback", "https://github.com/ocaml/opam-repository.git"]);
		cygCommand("opam",["repo", "set-repos", "default", "fallback"]);
		cygCommand("opam",["install","--yes"].concat(CFG.opamLibs));

		Sys.println("DONE");
	}

	static function main() {
		if( sys.FileSystem.exists("Build.hx") ) Sys.setCwd("..");
		new Build().build();
	}

}
