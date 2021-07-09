unit module App::Racoco::CoveredLinesCollector;

use App::Racoco::RunProc;
use App::Racoco::Paths;
use App::Racoco::X;

class CoveredLinesCollector is export {
  has IO::Path $.lib;
  has RunProc $.proc;
  has $.exec;
  has Bool $.append = False;
  has Bool $.print-test-log = True;
  has $!coverage-log-path;

  submethod TWEAK() {
    $!lib = $!lib.absolute.IO;
    $!coverage-log-path = coverage-log-path(:$!lib);
    $!coverage-log-path.unlink unless self!need-save-log;
  }

  method !need-save-log() {
    $!append || !$!exec
  }

  method collect(--> Associative) {
    self!run-tests();
    self!parse-log;
  }

  method !run-tests() {
    return unless $!exec;
    my $arg = "MVM_COVERAGE_LOG=$!coverage-log-path $!exec";
    my $proc = $!print-test-log ?? $!proc.run($arg) !! $!proc.run($arg, :!out);
    if $proc.exitcode {
      App::Racoco::X::NonZeroExitCode.new(exitcode => $proc.exitcode).throw
    }
  }

  method !parse-log(--> Associative) {
    return %{} unless $!coverage-log-path.e;
    my $prefix = 'HIT  ' ~ $!lib;
    my $prefix-len = $prefix.chars + '/'.chars;
    my @t = $!coverage-log-path.lines .grep(*.starts-with($prefix));
    dd @t[0];
      my @tt = @t.map(*.substr($prefix-len));
    dd @tt[0];
      my @t_unique = @tt.unique;
      my @t_t = @t_unique.map(-> $h { .[0] => .[2] with $h.words});
    dd @t_t[0];
      my @tc = @t_t.classify({ $_.key });
    dd @tc[0];
      my @tm = @tc.map({ $_.key => $_.value.map(*.value.Int).Set });
    dd @tm[0];
      my %result = @tm.Hash;

      return %result;
  }
}

