use Test;
use lib 'lib';
use lib 't/lib';
use App::Racoco::RunProc;
use App::Racoco::TmpDir;
use App::Racoco::Fixture;

plan 4;

my $sources = create-tmp-dir('racoco-tests');
my $test-file = $sources.add('file');

{
	my $out = $test-file.open(:w);
	LEAVE { .close with $out }
	my $result = RunProc.new.run('echo boom', :$out);
	ok $test-file.e, 'run echo into file';
	is $test-file.slurp.trim, 'boom', 'echo into file correct';
	is $result.exitcode, 0, 'exitcode 0';
}

{
	Fixture::suppressErr;
  LEAVE { Fixture::restoreErr }
	nok RunProc.new.run('not-exists', :!err), 'run not-exists ok';
}

done-testing