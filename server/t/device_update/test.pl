#!/usr/bin/perl -I../
use strict;
use warnings;
use client;

my $A = client->new();
$A->device_update({ pushtoken_hex => "AD34A9EF72DC714CED" });
