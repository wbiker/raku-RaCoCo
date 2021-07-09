unit module App::Racoco::Report::ReporterHtml;

use Cro::WebApp::Template;

use App::Racoco::Report::Report;
use App::Racoco::Report::Reporter;
use App::Racoco::Report::ReporterBasic;
use App::Racoco::Paths;
use App::Racoco::ModuleNames;
use App::Racoco::ProjectName;

class ReporterHtml does Reporter is export {
  has ReporterBasic $!reporter is built;
  has IO::Path $!lib;
  has Bool $.color-blind is rw;

  method make-from-data(:%coverable-lines, :%covered-lines --> Reporter) {
    self.bless(reporter =>
      ReporterBasic.make-from-data(:%coverable-lines, :%covered-lines));
  }

  method read(IO::Path :$lib --> Reporter) {
    with ReporterBasic.read(:$lib) {
      self.bless(reporter => $_)
    } else {
      Nil
    }
  }

  method report(--> Report) {
    $!reporter.report
  }

  method write(IO::Path :$lib --> IO::Path) {
    $!lib = $lib;
    $!reporter.write(:$lib);
    my %module-links = self!write-module-pages();
    my $result = self!write-main-page(%module-links);
    self!write-main-page-url();
    $result
  }

  method !write-module-pages(--> Associative) {
    my $template = %?RESOURCES<report-file.crotmp>.IO;
    return $!reporter.report.all-data.map(-> $data {
      $data.file-name => self!write-module-page($data, $template)
    }).Map;
  }

  method !write-main-page(%module-links --> IO::Path) {
    my %data = project-name => project-name(:$!lib);
    %data<modules> = self!code-main-page-content(%module-links);
    my $template = %?RESOURCES<report.crotmp>.IO;
    my $content = render-template($template, %data);

    my $path = report-html-path(:$!lib);
    $path.spurt: $content;
    return $path;
  }

  method !write-main-page-url() {
    say "Visualisation: file://", report-html-path(:$!lib).Str
  }

  method !write-module-page(FileReportData $data, IO $template is copy--> Str) {
    my $path = report-html-data-path(:$!lib) .add(self!module-page-name($data.file-name));

    my %data;
    %data<pre> = self!code-module-content($data);
    %data<module-name> = module-name(:path($data.file-name));
    %data<percent> = $data.percent;
    %data<color-blind> = $!color-blind;

    my $result = render-template $template, %data;
    $path.spurt: $result;
    $path.Str.substr(report-html-data-path(:$!lib).Str.chars + '/'.chars)
  }

  method !module-page-name(Str $file-name --> Str) {
    module-parts(path => $file-name.IO).join('-') ~ '.html'
  }

  method !code-main-page-content(%module-links --> Array) {
    return $!reporter.report.all-data.map(-> $data {
      self!code-main-page-module-content($data, %module-links);
    }).Array;
  }

  method !code-main-page-module-content(FileReportData $data, %module-links --> Associative) {
      my %data;

      %data<link> = %module-links{$data.file-name};
      %data<module-name> = module-name(path => $data.file-name.IO);
      %data<percent> = $data.percent;
      %data<coverable> = $data.coverable;
      %data<covered> = $data.covered;

      return %data;
  }

  method !code-module-content(FileReportData $data --> Str) {
    $!lib.add($data.file-name).lines.kv.map(-> $i, $line {
      my $color = self!get-color($data, $i + 1);
      my $esc = self!esc-line($line);
      sprintf('<span class="coverage-%s">%s</span>', $color, $esc)
    }).join("\n")
  }

  method !get-color($data, $line) {
    ($data.color(:$line) // 'no').lc;
  }

  method !esc-line($line) {
    $line.trans(['<', '>', '&', '"'] => [ '&lt;', '&gt;', '&amp;', '&quot;' ])
  }
}