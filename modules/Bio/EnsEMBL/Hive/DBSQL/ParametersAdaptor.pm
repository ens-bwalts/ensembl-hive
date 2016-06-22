=pod

=head1 NAME

    Bio::EnsEMBL::Hive::DBSQL::ParametersAdaptor

=head1 SYNOPSIS

    $parameters_adaptor = $db_adaptor->get_ParametersAdaptor;

=head1 DESCRIPTION

    This module deals with parameters' storage and retrieval

=head1 LICENSE

    Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=cut


package Bio::EnsEMBL::Hive::DBSQL::ParametersAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils ('destringify', 'stringify');

use base ('Bio::EnsEMBL::Hive::DBSQL::NakedTableAdaptor');


sub default_table_name {
    return 'parameters';
}


sub default_load_transform {
    return {
        'param_value' => sub { return destringify(pop @_); },
    };
}


sub slicer {    # take a slice of the object (if only we could inline in Perl!)
    my ($self, $hashref, $fields) = @_;

    return [ map { ($_ eq 'param_value') ? stringify($hashref->{$_}) : $hashref->{$_}; } @$fields ];
}


sub fetch_param_hashrefs_for_job_ids {
    my ($self, $job_ids_csv, $id_scale, $id_offset) = @_;
    $id_scale   ||= 1;
    $id_offset  ||= 0;

    my %param_hashrefs = ();

    if( $job_ids_csv ) {

        my $sql = "SELECT job_id, param_name, param_value FROM parameters WHERE job_id in ($job_ids_csv)";
        my $sth = $self->prepare( $sql );
        $sth->execute();

        while(my ($job_id, $param_name, $param_value) = $sth->fetchrow_array() ) {
            $param_hashrefs{$job_id * $id_scale + $id_offset}{ $param_name } = destringify($param_value);
        }
    }
    return \%param_hashrefs;
}


sub fetch_job_parameters_hashref {
    my ($self, $job_id) = @_;

    my $job_parameters = $self->fetch_by_job_id_AND_origin_param_id_HASHED_FROM_param_name_TO_param_value($job_id, undef);

        # overflow targets:
    my $overflow_index_to_param_names = $self->fetch_all_by_job_id_AND_param_value_HASHED_FROM_origin_param_id_TO_param_name($job_id, undef);

    if(%$overflow_index_to_param_names) {
            # overflow sources:
        my $overflow_index_to_param_value = $self->fetch_all( 'param_id IN ('.join(', ', keys %$overflow_index_to_param_names).')', 1, ['param_id'], 'param_value' );

        while(my ($param_id, $param_names) = each %$overflow_index_to_param_names) {
            if(exists $overflow_index_to_param_value->{$param_id}) {
                my $param_value = $overflow_index_to_param_value->{$param_id};
                @$job_parameters{@$param_names} = ($param_value) x scalar(@$param_names);   # Assigning an array to a hashref slice!
            } else {
                die "Parameter referred to by param_id='$param_id' not found";
            }
        }
    }

    return $job_parameters;
}


sub fetch_analysis_parameters_hashref {
    my ($self, $analysis_id) = @_;

    return $self->fetch_by_analysis_id_HASHED_FROM_param_name_TO_param_value($analysis_id);
}


sub fetch_pipeline_wide_parameters_hashref {
    my ($self) = @_;

    return $self->fetch_by_job_id_AND_analysis_id_HASHED_FROM_param_name_TO_param_value(undef, undef);
}

1;