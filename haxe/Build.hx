class Build {

	var cygwinPath : String;

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

	function cygCopyFile( file : String, out : String ) {
		try sys.io.File.copy(cygwinPath + "/" + file, "mingw/" + out + "/" + file) catch( e : Dynamic ) log("*** MISSING " + file+" in your Cygwin install ***");
	}

	function detectCygwin() {
		var p = new sys.io.Process("where.exe",["cygpath.exe"]);
		if( p.exitCode() != 0 ) {
			log("Cygwin not found");
			Sys.exit(1);
		}
		cygwinPath = StringTools.trim(p.stdout.readAll().toString()).substr(0,-11);
	}

	function build() {

		// build minimal mingw distrib to use if the user doesn't have cygwin installed

		detectCygwin();
		makeDir("mingw/bin");
		for( f in Config.REQUIRED_TOOLS )
			cygCopyFile(f + ".exe", "bin");

		return;

		// build opam repo with packages necessary for haxe

		var opam = "opam32.tar.xz";
		var ocaml = "4.03.0+mingw32";

		deleteFile(opam);
		command("wget",["https://github.com/fdopen/opam-repository-mingw/releases/download/0.0.0.1/"+opam]);
		command("tar",["-xf",opam,"--strip-components","1"]);
		deleteFile(opam);
		deleteFile("install.sh");

		var opamPath = Sys.getCwd().split("\\").join("/")+".opam";
		cygCommand("bin/opam",["init","--yes","--root",opamPath,"default","https://github.com/fdopen/opam-repository-mingw.git","--comp",ocaml,"--switch",ocaml]);
		cygCommand("bin/opam",["install","--yes","--root",opamPath,"sedlex","camlp4","merlin"]);
	}

	static function main() {
		new Build().build();
	}

}