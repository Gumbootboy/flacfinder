use WWW::Mechanize;
use Mojo::DOM;
use HTTP::Cookies;
use Data::Dumper qw(Dumper);
use Config::Simple;
#search latest or X on apollo eg most recent, largest, 2016 flacs
#search for all torrents containing the title, or by all artists (excl VA)
#store all as Torrents
#run fuzzy compare function on data,

# Get information from config file
my %config;
Config::Simple->import_from('config.ini', \%config);

my $mech = WWW::Mechanize->new();

my $page = 1;
my $url = "http://apollo.rip/index.php";

$mech->cookie_jar(HTTP::Cookies->new());
$mech->get($url);
$mech->form_name("login");
$mech->set_fields(username=>$config{'apollo.username'},password=>$config{'apollo.password'});
$mech->click();

my $dom = Mojo::DOM->new($mech->content);
my %torrents;
my $index = 0;

for($page = 1; $page < 2; $page++){
  print "Starting Page $page";
  $url = "http://apollo.rip/torrents.php?page=" . $page . "&encoding=Lossless&format=FLAC&media=CD&haslog=100&hascue=1&order_by=time&order_way=desc&action=advanced&searchsubmit=1";
  $mech->get($url);
  $dom = Mojo::DOM->new($mech->content);
  parseTorrents();
  print "\nPage $page Done.\n";
  sleep(2);
}

$url = $config{'pth.login-url'};
$mech->cookie_jar(HTTP::Cookies->new());
$mech->get($url);
$mech->save_content("what2out.html");
$mech->form_name("login");
$mech->set_fields(username=>$config{'pth.username'},password=>$config{'pth.password'});
$mech->click();
$mech->save_content("what2in.html");

for($i = 0; $i < 5; $i++){
  $searchNo = $i + 1;
  print "Starting Search #$searchNo\n";
  checkAvailability($i);
  sleep(2);
  print "Search #$searchNo Completed.\n\n";
}

#print Dumper \%torrents;

sub parseTorrents(){
  # Loop through each torrent result
  for my $e ($dom->find('tr.torrent')->each) {

    my $year;
    my $size;
    my $title;
    my $link;
    my @artists = ();
    my @tags = ();

    # YEAR
    for my $f ($e->find('td.big_info div.group_info.clear')->each) {
      ($year) = $f =~ /\[(\w+)\]/;
    }

    # SIZE
    for my $f ($e->find('td.number_column.nobr')->each) {
      if ($f=~/MB|GB/){
        $size = $f->text;
      }
    }

    # LINKS
    for my $f ($e->find('td.big_info div.group_info.clear a')->each) {
      my $href = $f->attr('href');
      my @href = split /[?,&,=]+/, $href;
      my $text = $f->text;

      # DOWNLOAD LINK
      if($href=~/torrents.php\?action=download&id=/){
        #print "Download Link: " . $href; 
      }    

      # REPORT LINK
      if($href=~/reportsv2.php\?action=report&id=/){
        #print "Report Link: " . $href; 
      }    

      # ARTIST
      if($href=~/artist.php\?id=/){
        push(@artists, $text);
      }    

      # TITLE
      if($href=~/torrents.php\?id=/){
        $link = $href;     
        $title = $text;
      }    

      # TAGS
      if($href=~/torrents.php\?action=advanced&taglist=/){
        push(@tags, $text);
      }     
    }

    #FIX ARTIST ARRAY
    my $artistsSize = @artists;

    if($artistsSize == 0){
      $torrents{$index}{'artists'} = "Various Artists";  
    }
    if($artistsSize == 1){
      $torrents{$index}{'artists'} = @artists[0];  
    }
    if($artistsSize == 2){
      $torrents{$index}{'artists'} = \@artists;  
    }

    #checkAvailability();

    #POPULATE HASH 
    $torrents{$index}{'title'} = $title;
    $torrents{$index}{'year'} = $year;  
    $torrents{$index}{'size'} = $size;
    $torrents{$index}{'tags'} = \@tags;  
    
    $mech->save_content("what-page-" . $page  . ".html");

    $index++;
  }
}

sub checkAvailability(){
  my ($torrentIndex) = @_;
  my $searchTitle = $torrents{$torrentIndex}{"title"};
  print $searchTitle . "\n";

  #https://passtheheadphones.me/torrents.php?searchstr=XXX&format=FLAC&haslog=100&hascue=1&order_by=time&order_way=desc&action=advanced&searchsubmit=1
  $url = "https://passtheheadphones.me/torrents.php?searchstr=" . $searchTitle . "&format=FLAC&haslog=100&hascue=1&order_by=time&order_way=desc&action=advanced&searchsubmit=1";

  $mech->get($url);
  $dom = Mojo::DOM->new($mech->content);

  if($dom=~/Your search did not match anything./){
    print "No Results!\n";
  }
  else{
    my $countResults = 0;
    for my $g ($dom->find('tr.torrent')->each) {
      $countResults++;
    }

    #too many results > 50 -> combine with artist(s)
    #else -> look for artist(s)
    print "$countResults Results!!\n";
  }

  $mech->save_content("what2-" . $searchTitle . ".html");

}
