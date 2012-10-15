package Cennel::Defs::Statuses;
use strict;
use warnings;
use Exporter::Lite;

our @EXPORT;

sub OPERATION_UNIT_STATUS_INITIAL { 1 }
sub OPERATION_UNIT_STATUS_STARTED { 2 }
sub OPERATION_UNIT_STATUS_FAILED { 3 }
sub OPERATION_UNIT_STATUS_SUCCEEDED { 4 }
sub OPERATION_UNIT_STATUS_PRECONDITION_FAILED { 5 }
sub OPERATION_UNIT_STATUS_SKIPPED { 6 }

push @EXPORT, qw(
    OPERATION_UNIT_STATUS_INITIAL
    OPERATION_UNIT_STATUS_STARTED
    OPERATION_UNIT_STATUS_FAILED
    OPERATION_UNIT_STATUS_SUCCEEDED
    OPERATION_UNIT_STATUS_PRECONDITION_FAILED
    OPERATION_UNIT_STATUS_SKIPPED
);

1;
