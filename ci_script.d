import std.process;
import std.file;
import std.process;
import std.stdio;

// Commandline args
string[] unitThreadedArgs;

// Utils ///////////////////////////////////////////////

bool envBool(string name)
{
	return environment.get(name, null) == "true";
}

string envGet(string name)
{
	return environment.get(name, null);
}

void copyIfExists(string from, string to)
{
	if(exists(from) && isFile(from))
		copy(from, to);
}

void tryMkdir(string dir)
{
	if(!exists(dir))
		mkdir(dir);
}

int run(string command)
{
	writeln(command);
	return spawnShell(command).wait;
}

// Main ///////////////////////////////////////////////

int main(string[] args)
{
	unitThreadedArgs = args[1..$];

	//writeln("unitThreadedArgs: ", unitThreadedArgs);

	// GDC doesn't autocreate the dir (and git doesn't beleive in empty dirs)
	tryMkdir("bin");

	// If an alternate dub.selections.json was requested, use it.
	copyIfExists("dub.selections."~envGet("DUB_SELECT")~".json", "dub.selections.json");

	if(envBool("DUB_UPGRADE"))
	{
		// Update all dependencies
		//
		// As a bonus, this downloads & resolves deps now so intermittent
		// failures are more likely to be correctly marked as "job error"
		// rather than "tests failed".
		spawnShell("dub upgrade").wait;
	}
	else
	{
		// Don't upgrade dependencies.
		//
		// But download & resolve deps now so intermittent failures are more likely
		// to be correctly marked as "job error" rather than "tests failed".
		spawnShell("dub upgrade --missing-only").wait;
	}

	if(envBool("NO_UT"))
		return run("dub run -c unittest-builtin");
	else
		return run("dub test");
}
