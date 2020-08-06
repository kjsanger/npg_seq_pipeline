use strict;
use warnings;
use Cwd;
use Test::More tests => 4;
use Test::Exception;

my $runfolder_path = 't/data/novaseq/200709_A00948_0157_AHM2J2DRXX';
my $bbc_path = join q[/], getcwd(), $runfolder_path,
               'Data/Intensities/BAM_basecalls_20200710-105415';

local $ENV{NPG_CACHED_SAMPLESHEET_FILE} = join q[/], $bbc_path,
        'metadata_cache_34576/samplesheet_34576.csv';

my $pkg = 'npg_pipeline::function::pp_data_to_irods_archiver';
use_ok($pkg);

subtest 'local flag' => sub {
  plan tests => 3;

  my $archiver = $pkg->new
      (conf_path      => 't/data/release/config/pp_archival',
       id_run         => 34576,
       runfolder_path => $runfolder_path,
       local          => 1);

  my $ds = $archiver->create;
  is(scalar @{$ds}, 1, 'one definition is returned');
  isa_ok($ds->[0], 'npg_pipeline::function::definition');
  is($ds->[0]->excluded, 1, 'function is excluded');
};

subtest 'no_irods_archival flag' => sub {
  plan tests => 3;

  my $archiver = $pkg->new
    (conf_path         => 't/data/release/config/pp_archival',
     id_run            => 34576,
     runfolder_path    => $runfolder_path,
     no_irods_archival => 1);
  my $ds = $archiver->create;
  is(scalar @{$ds}, 1, 'one definition is returned');
  isa_ok($ds->[0], 'npg_pipeline::function::definition');
  is($ds->[0]->excluded, 1, 'function is excluded');
};

subtest 'run archival' => sub {
  plan tests => 14;

  my $archiver = $pkg->new
    (conf_path         => 't/data/release/config/pp_archival',
     id_run            => 34576,
     timestamp         => '20200806-130730',
     runfolder_path    => $runfolder_path);
  my $ds = $archiver->create;

  my $num_expected = 407;
  is(scalar @{$ds}, $num_expected, "expected $num_expected definitions");
  my $d = $ds->[0];
  isa_ok($d, 'npg_pipeline::function::definition');
  ok (!$d->excluded, 'function is not excluded');
  is ($d->queue, 'lowload', 'queue is lowload');
  ok ($d->reserve_irods_slots, 'reserve_irods_slots flag is true');
  is ($d->fs_slots_num, 1, 'number of fs slots is 1');
  ok ($d->composition, 'composition attribute is defined');
  is ($d->composition->freeze2rpt, '34576:1:1',
    'composition is for lane 1 plex 1');
  ok ($d->command_preexec, 'command preexec is defined');
  is ($d->identifier, 34576, 'job identifier is run id');
  is ($d->created_by, $pkg, "definition created by $pkg");
  is ($d->created_on, '20200806-130730', 'correct timestamp');
  is ($d->job_name, 'pp_data_to_irods_archiver_34576_20200806-130730',
    'job_name is correct');
  is ($d->command, 'npg_publish_tree.pl' . 
    q( --collection /seq/illumina/pp/runs/34/34576/lane1/plex1) .
    q( --source ) . $bbc_path . q(/pp_archive/lane1/plex1) .
    q( --include 'ncov2019_artic_nf/v0.(7|8)\\b\\S+trim\\S+/\\S+bam') .
    q( --include 'ncov2019_artic_nf/v0.(11)\\b\\S+trim\\S+/\\S+cram') .
    q( --include 'ncov2019_artic_nf/v0.\\d+\\b\\S+make\\S+/\\S+consensus.fa') .
    q( --include 'ncov2019_artic_nf/v0.\\d+\\b\\S+call\\S+/\\S+variants.tsv'),
    'correct command');
};

