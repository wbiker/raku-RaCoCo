unit module Racoco::Annotation;

use Racoco::Precomp::PrecompSupplier;
use Racoco::PrecompFile;
use Racoco::Paths;
use Racoco::UtilExtProc;

class Annotation is export {
  has Str $.file;
  has Instant $.timestamp;
  has Str $.hashcode;
  has @.lines;

  method Str() {
    "Annotation($!file)[{$!timestamp.to-posix[0]}]{$!hashcode}: @!lines[]"
  }
}

role Dumper is export {
  method get($file) { ... }
}
class DumperReal does Dumper is export {
  has RunProc $.proc;
  has Str $.moar;

  method get($file) {
    my $arg = "$!moar --dump $file";
    my $proc = $!proc.run($arg, :out);
    LEAVE { $proc.out.close if $proc && $proc.out }
    return () if $proc.exitcode;
    $proc.out.lines
      .grep(*.starts-with: '     annotation:')
      .map(*.split(':')[*-1].Int)
      .unique
      .sort
      .eager
      .List
  }
}

role Index is export {
  method get($path) { ... }
  method add($annotation) { ... }
  method flush() { ... }
}
class IndexFile does Index is export {
  has IO::Path $.path;
  has %!annotations;

  submethod TWEAK(:$lib) {
    $!path = $lib.parent.add(DOT-RACOCO).add(INDEX);
    %!annotations = self!read-index();
  }

  method !read-index() {
    return %{} unless $!path.e;
    $!path.lines.map(-> $l {
      my ($file, $timestamp, $hashcode, $lines) =
        $l.split('|').map(*.trim).List;

      my $annotation = Annotation.new(:$file, :hashcode($hashcode // ''),
        :timestamp(self!parse-timestamp($timestamp)),
        :lines(self!parse-lines($lines))
      );

      $annotation.timestamp && $annotation.hashcode
        ?? $annotation !! Annotation
    })
    .grep(*.so).map(-> $a { $a.file => $a }).eager.Map;
  }

  method !parse-lines($lines) {
    ($lines // '').trim.split(' ').grep(*.so).map(*.Int).eager.sort.List
  }

  method !parse-timestamp($timestamp) {
    try Instant.from-posix($timestamp.trim);
  }

  method get($path) {
    %!annotations{$path.Str}
  }

  method add($annotation) {
    %!annotations{$annotation.file} = $annotation
  }

  method flush() {
    $!path.parent.mkdir;
    my $h = $!path.open(:w);
    LEAVE { .close with $h }
    %!annotations.sort.map(*.value)
      .map(-> $a { self!serialize-annotation($a)})
      .map(-> $s { $h.say($s.trim)});
    Nil
  }

  method !serialize-annotation($annotation) {
    with $annotation -> $a {
      ($a.file, $a.timestamp.to-posix[0], $a.hashcode, $a.lines.Str)
        .join(' | ');
    }
  }
}

class Calculator is export {
  has PrecompSupplier $.supplier;
  has Index $.index;
  has HashcodeGetter $.hashcodeGetter;
  has Dumper $.dumper;

  method calc-and-update-index(IO() $path) {
    my $precomp = $!supplier.supply(file-name => $path.Str);
    return () without $precomp;
    my $hashcode = $!hashcodeGetter.get($precomp);
    my $index = $!index.get($path);
    my $new-index;
    if self!is-actual($index, $precomp, $hashcode) {
      $new-index = $index;
    } else {
      $new-index = Annotation.new(
        file => $path.Str,
        timestamp => $precomp.modified,
        hashcode => $hashcode,
        lines => $!dumper.get($precomp)
      )
    }
    $!index.add($new-index);
    $new-index.lines
  }

  method !is-actual($index, $precomp, $hashcode) {
    $index &&
    $index.timestamp >= $precomp.modified &&
    $index.hashcode eq $hashcode
  }
}

class AnnotationCollector is export {
  has IO::Path $.lib;
  has Calculator $.calculator;
  has Int $!lib-path-len;

  submethod TWEAK() {
    $!lib-path-len = $!lib.Str.chars + '/'.chars;
  }

  method get() {
    return %{} unless $!lib.e;
    self!iter-through($!lib, %{});
  }

  method !iter-through($dir, %collect) {
    for $dir.dir -> $l {
      if $l.d {
        self!iter-through($l, %collect);
      } elsif $l.extension eq any('rakumod', 'pm6') {
        my $path = $l.Str.substr($!lib-path-len);
        my $lines = $!calculator.calc-and-update-index($path);
        %collect{$path} = $lines.Set if $lines;
      }
    }
    %collect
  }
}