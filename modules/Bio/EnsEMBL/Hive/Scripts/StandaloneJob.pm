=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


package Bio::EnsEMBL::Hive::Scripts::StandaloneJob;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Hive::AnalysisJob;
use Bio::EnsEMBL::Hive::Utils ('load_file_or_module', 'stringify', 'destringify');

sub standaloneJob {
    my ($module_or_file, $input_id, $flags, $flow_into) = @_;

    my $runnable_module = load_file_or_module( $module_or_file );
    die "$module_or_file not loaded\n" unless $runnable_module;

    my $runnable_object = $runnable_module->new();
    die "Runnable $module_or_file not created\n" unless $runnable_object;
    $runnable_object->debug($flags->{debug}) if $flags->{debug};
    $runnable_object->execute_writes(not $flags->{no_write});

    my $job = Bio::EnsEMBL::Hive::AnalysisJob->new( 'dbID' => -1 );
    die "Dummy job not created\n" unless $job;
    $job->input_id( $input_id );
    $job->dataflow_rules(1, []);

    $job->param_init( $runnable_object->strict_hash_format(), $runnable_object->param_defaults(), $job->input_id() );

    $flow_into = $flow_into ? destringify($flow_into) : []; # empty dataflow for branch 1 by default
    $flow_into = { 1 => $flow_into } unless(ref($flow_into) eq 'HASH'); # force non-hash into a hash
    foreach my $branch_code (keys %$flow_into) {
        my $heirs = $flow_into->{$branch_code};

        $heirs = [ $heirs ] unless(ref($heirs)); # force scalar into an arrayref first
        $heirs = { map { ($_ => undef) } @$heirs } if(ref($heirs) eq 'ARRAY'); # now force it into a hash if it wasn't

        my @dataflow_rules = ();

        while(my ($heir_url, $input_id_template_list) = each %$heirs) {

            $input_id_template_list = [ $input_id_template_list ] unless(ref($input_id_template_list) eq 'ARRAY');  # allow for more than one template per analysis

            foreach my $input_id_template (@$input_id_template_list) {

                push @dataflow_rules, Bio::EnsEMBL::Hive::DataflowRule->new(
                    'to_analysis_url'   => $heir_url,
                    'input_id_template' => $input_id_template,
                );
            }
        }
        $job->dataflow_rules( $branch_code, \@dataflow_rules );
    }

    $runnable_object->input_job($job);
    $runnable_object->life_cycle();

    $runnable_object->cleanup_worker_temp_directory() unless $flags->{no_cleanup};

    return !$job->died_somewhere()
}


1;
