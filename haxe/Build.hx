import haxe.io.Path;

typedef BuildConfig = {
	var skipMinGWCopy:Bool;
	var skipOpamSetup:Bool;
	var skipOpamRepoInit:Bool;
}

class Build {

	static var CFG = @:privateAccess Config.CFG;

	var config:BuildConfig;

	var cygwinPath(default, set) : String;
	var cygwinBinPath : String;

	function set_cygwinPath(value:String) {
		this.cygwinPath = value;
		cygwinBinPath = Path.join([cygwinPath, "bin"]);
		return value;
	}

	function new(config:BuildConfig) {
		this.config = config;
	}

	static function log( msg : String ) {
		Sys.println(msg);
	}

	static function error(msg:String) {
		log('[ERROR] $msg');
	}

	function command(cmd,args:Array<String>) {
		log("> "+cmd+" "+args.join(" "));
		var r = Sys.command(cmd,args);
		if( r != 0 ) throw "Command exit with code "+r;
	}

	function deleteFile(path:String) {
		try {
			log('> rm $path');
			sys.FileSystem.deleteFile(path);
		}
		catch(e : Dynamic) {

		}
	}

	function makeDir(path:String) {
		try sys.FileSystem.createDirectory(path) catch(e:Dynamic) {}
	}

	function cygCommand(cmd,args:Array<String>) {
		command("bash",["-c",cmd+" "+args.join(" ")]);
	}

	var copiedFiles = new Map();

	function cygCopyFile( file : String ) {

		var source = cygwinPath + "/" + file;
		var destination = "mingw/" + file;
		copiedFiles.set(file, true);
		try {
			var path = new Path(destination);
			makeDir(path.dir);
			sys.io.File.copy(source, destination);
		 } catch( e : Dynamic ) {
			log('*** Could not copy $source to $destination: $e ***');
		 }

		if( !StringTools.endsWith(file.toLowerCase(),".exe") && !StringTools.endsWith(file.toLowerCase(),".dll") )
			return;

		// look for dll dependencies
		var o = try {
			new sys.io.Process("dumpbin.exe",["/IMPORTS","mingw/"+file]);
		} catch(e:Dynamic) {
			error("Could not execute dumpbin, make sure it's in your PATH or run from a Visual Studio CLI");
			Sys.exit(1);
			null;
		}
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
			error("Cygwin not found");
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

		if (!config.skipMinGWCopy) {
			Sys.println("Preparing mingw distrib...");
			makeDir("mingw/bin");
			for( f in CFG.cygwinTools )
				cygCopyFile("bin/"+ f.split("$MINGW").join(mingw) + ".exe");
			cygCopyDir('usr/$mingw');
			cygCopyDir('lib/gcc/$mingw');
			makeDir("mingw/tmp");
		}

		var opam = 'opam$bits.tar.xz';
		var ocaml = CFG.ocamlVersion + '+mingw$bits';

		if (!config.skipOpamSetup) {
			// build opam repo with packages necessary for haxe

			Sys.println("Preparing opam...");

			if( !sys.FileSystem.exists("bin") ) {
				// install opam
				deleteFile(opam);
				command("wget",[CFG.opamUrl+opam, "-q"]);
				command(Path.join([cygwinBinPath, "tar"]),["-xf",opam,"--strip-components","1"]);
				deleteFile(opam);
				deleteFile("install.sh");
			}
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

		if (!config.skipOpamRepoInit) {
			if( !sys.FileSystem.exists(opamRoot) )
				cygCommand("opam",["init","--yes","default","https://github.com/ocaml-opam/opam-repository-mingw.git#sunset","--comp",ocaml,"--switch",ocaml]);

			cygCommand("opam",["switch",ocaml]);
			cygCommand("opam",["repo", "add", "fallback", "https://github.com/ocaml/opam-repository.git"]);
			cygCommand("opam",["repo", "set-repos", "default", "fallback"]);
		}
		cygCommand("opam",["install","--yes"].concat(CFG.opamLibs));

		Sys.println("DONE");
	}

	static function main() {
		if( sys.FileSystem.exists("Build.hx") ) Sys.setCwd("..");
		var config = {
			skipMinGWCopy: false,
			skipOpamSetup: false,
			skipOpamRepoInit: false
		}

		#if hxargs
		var help = false;

		var argParser = hxargs.Args.generate([
			@doc("Skip copy to mingw directory so the program can execute without dumpbin")
			"--skip-mingw-copy" => function() {
				config.skipMinGWCopy = true;
			},

			@doc("Skip opam setup")
			"--skip-opam-setup" => function() {
				config.skipOpamSetup = true;
			},

			@doc("Skip opam repository init")
			"--skip-opam-repo-init" => function() {
				config.skipOpamRepoInit = true;
			},

			@doc("Show this help message")
			"--help" => function() {
				help = true;
			}
		]);
		argParser.parse(Sys.args());

		if (help) {
			Sys.println(argParser.getDoc());
			Sys.exit(0);
		}
		#else
		if (Sys.args().length > 0) {
			error("Command line arguments are only supported with -lib hxargs");
			Sys.exit(1);
		}
		#end
		new Build(config).build();
	}

}
