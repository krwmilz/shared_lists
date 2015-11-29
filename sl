#!/usr/bin/perl
$| = 1;
use warnings;
use strict;

use BSD::arc4random qw(:all);
use DBI;
use Digest::SHA qw(sha256_base64);
use Getopt::Std;
use IO::Socket qw(getnameinfo NI_NUMERICHOST NI_NUMERICSERV);
use POSIX;
use Scalar::Util qw(looks_like_number);
use Socket;

require "msgs.pl";
our (%msg_num, @msg_str, @msg_func, $protocol_ver);

my $LOG_LEVEL_ERROR = 0;
my $LOG_LEVEL_WARN = 1;
my $LOG_LEVEL_INFO = 2;
my $LOG_LEVEL_DEBUG = 3;
my $LOG_LEVEL = $LOG_LEVEL_INFO;

my %args;
getopts("p:d:", \%args);

my $db_file = "db";
if ($args{d}) {
	$db_file = $args{d};
	unlink $db_file;
}
elsif (! -e $db_file) {
	print "info: creating new database '$db_file'\n";
}

create_tables();

my $sock = new IO::Socket::INET (
	LocalHost => '0.0.0.0',
	LocalPort => $args{p} || '5437',
	Proto => 'tcp',
	Listen => 100,
	Reuse => 1,
);
die "Could not create socket: $!\n" unless $sock;
my $local_addr_port = inet_ntoa($sock->sockaddr) . ":" .$sock->sockport();

$SIG{CHLD} = 'IGNORE';

while (my ($new_sock, $bin_addr) = $sock->accept()) {

	next if (!$new_sock);

	my $pid = fork();
	if (!defined $pid) {
		die "error: can't fork: $!\n";
	} elsif ($pid) {
		close $new_sock;
		next;
	}
	# after here we're in the child

	my $dbh = DBI->connect(
		"dbi:SQLite:dbname=$db_file",
		"", "",
		{ RaiseError => 1 }
	) or die $DBI::errstr;
	$dbh->do("PRAGMA foreign_keys = ON");
	$dbh->{AutoCommit} = 1;

	my $stmt_handles = prepare_stmt_handles($dbh);

	# don't try and resolve ip address or port
	my ($err, $addr, $port) = getnameinfo($bin_addr, NI_NUMERICHOST | NI_NUMERICSERV);
	print "warn: getnameinfo() failed: $err\n" if ($err);

	$addr = sprintf "%s %-15s %-5s", strftime("%F %T", localtime), $addr, $port;
	print "$addr: new connection (pid = '$$')\n";

	# read will be 0 when there's nothing else to read
	while (my $bread = read $new_sock, my $metadata, 4) {
		# i'm not sure if read is guaranteed to read all 4 bytes
		if ($bread != 4) {
			print "warn: $addr: read $bread instead of 4 bytes\n";
			last;
		}
		# try to extract msg type and size to two unsigned shorts
		my ($msg_type, $msg_size) = unpack("nn", $metadata);

		# validate message type
		if (!defined $msg_type) {
			print "$addr: error unpacking msg type\n";
			last;
		} elsif ($msg_type > @msg_str) {
			print "$addr: unknown message type " . sprintf "0x%x\n", $msg_type;
			last;
		}

		# validate message size
		if (!defined $msg_size) {
			print "$addr: error unpacking msg size\n";
			last;
		}
		if ($msg_size == 0 || $msg_size > 1024) {
			print "$addr: message size not 0 < $msg_size <= 1024\n";
			last;
		}

		# read exact amount of bytes the message should be
		# XXX: not sure if this is optimal
		$bread = read($new_sock, my $msg, $msg_size);
		if ($bread != $msg_size) {
			print "warn: $addr: read $bread instead of $msg_size\n";

			if ($bread < $msg_size) {
				print "warn: $addr: $bread too small, scrapping msg\n";
				last;
			}
			# we read more bytes than we were expecting, keep going
		}

		$dbh->begin_work;
		# call the appropriate handler
		my $hdr = "$addr $msg_str[$msg_type]";
		$msg_func[$msg_type]->($dbh, $stmt_handles, $new_sock, $hdr, $msg);

		$dbh->commit;   # commit the changes if we get this far
		if ($@) {
			warn "Transaction aborted because $@";
			# now rollback to undo the incomplete changes
			# but do it in an eval{} as it may also fail
			eval { $dbh->rollback };
			# add other application on-error-clean-up code here
		}
	}

	for my $sth (keys %$stmt_handles) {
		# $stmt_handles->{$sth}->finish;
		$stmt_handles->{$sth} = undef;
	}

	print "$addr: disconnected!\n";
	close($new_sock);
	$dbh->disconnect();
	exit 0;
}

sub get_phone_number
{
	my ($dbh, $sth, $device_id) = @_;

	#print "info: get_phone_number() unimplemented, returning device id!\n";
	#return $device_id;
	my (undef, $ph_num) = $dbh->selectrow_array($sth->{device_id_exists}, undef, $device_id);
	unless (defined $ph_num && looks_like_number($ph_num)) {
		print "warn: phone number lookup for $device_id failed!\n";
		return "000";
	}

	return $ph_num;
}

sub msg_new_device
{
	my ($dbh, $sth_ref, $new_sock, $addr, $msg) = @_;
	my %sth = %$sth_ref;

	# single field
	my $ph_num = $msg;

	if (!looks_like_number($ph_num)) {
		print "$addr: device phone number $ph_num invalid\n";
		return;
	}
	if ($dbh->selectrow_array($sth{ph_num_exists}, undef, $ph_num)) {
		print "$addr: phone number $ph_num already exists\n";
		return;
	}

	# make a new device id, the client will supply this on all
	# further communication
	# XXX: need to check the db to make sure this isn't duplicate
	my $token = sha256_base64(arc4random_bytes(32));

	print $new_sock pack("nn", 0, length($token));
	print $new_sock $token;
	$sth{new_device}->execute($token, $ph_num, time);
	print "$addr: added new device '$ph_num' '" .fingerprint($token). "'\n";
}

sub msg_new_list
{
	my ($dbh, $sth_ref, $new_sock, $addr, $msg) = @_;
	my %sth = %$sth_ref;

	# expecting two fields delimited by null
	my ($device_id, $list_name) = split("\0", $msg);

	# validate input
	return if (device_id_invalid($dbh, $sth_ref, $device_id, $addr));
	unless ($list_name) {
		print "$addr: list name missing\n";
		return;
	}
	my $devid_fp = fingerprint($device_id);

	print "$addr: '$list_name'\n";
	print "$addr: adding first list member devid = '$devid_fp'\n";

	my $time = time;
	my $list_id = sha256_base64(arc4random_bytes(32));
	print "$addr: list fingerprint = '" .fingerprint($list_id). "'\n";

	# add new list with single list member
	$sth{new_list}->execute($list_id, $list_name, $time, $time);
	$sth{new_list_member}->execute($list_id, $device_id, $time);

	# XXX: also send back the date and all that stuff
	my $phone_number = get_phone_number($dbh, $sth_ref, $device_id);
	my $out = $list_id . "\0" . $list_name . "\0" . $phone_number;
	print $new_sock pack("nn", $msg_num{new_list}, length($out));
	print $new_sock $out;
}

sub msg_new_list_item
{
    my ($dbh, $sth_ref, $new_sock, $addr, $msg) = @_;

    # my ($list_id, $position, $text) = split ("\0", $msg);
    
    # print "info: $addr: list $list_id\n";
    # print "info: $addr: position\n";
    # print "info: $addr: text $text\n";

    # check that list exists
    # check if item exists
    # check for "" owner on a stack
    # either create or add to unowned stack
    # owner will be emtpy
    # last_update 
}

sub msg_join_list
{
    my ($dbh, $sth_ref, $new_sock, $addr, $msg, $sth) = @_;
    my %sth = %$sth_ref;
    my ($device_id, $list_id) = split("\0", $msg);

    return if (device_id_invalid($dbh, $sth_ref, $device_id, $addr));

    print "info: $addr: device '$device_id'\n";
    print "info: $addr: list '$list_id'\n";
    
    my $time = time;
    $sth{check_list_member}->execute($list_id, $device_id);

    if (!$sth{check_list_member}->fetchrow_array()) {
        $sth{new_list_member}->execute($list_id, $device_id, $time);
        print "info: $addr: device '$device_id' has been added to list $list_id\n";
    } else {
        print "warn: $addr: tried to create a duplicate list member entry for device $device_id and list $list_id\n";
    }

    print $new_sock pack("nn", 4, length($list_id));
    print $new_sock $list_id;
}

sub msg_leave_list
{
    my ($dbh, $sth_ref, $new_sock, $addr, $msg) = @_;
    my %sth = %$sth_ref;

    my ($device_id, $list_id) = split("\0", $msg);

    return if (device_id_invalid($dbh, $sth_ref, $device_id, $addr));
    
    print "info: $addr: device '$device_id'\n";
    print "info: $addr: list '$list_id'\n";

    $sth{check_list_member}->execute($list_id, $device_id);

    if ($sth{check_list_member}->fetchrow_array()) {
        $sth{remove_list_member}->execute($list_id, $device_id);
        print "info: $addr: device '$device_id' has been removed from list '$list_id'\n";
    } else {
        print "warn: $addr: tried to leave a list the user was not in for device '$device_id' and list '$list_id'\n";
    }
    $sth{check_list_member}->finish();

    $sth{get_list_members}->execute($list_id);
    
    my $alive = 1;

    if (!$sth{get_list_members}->fetchrow_array()) {
        print "info: $addr: list '$list_id' is empty... deleting\n";
        $sth{delete_list}->execute($list_id);
        $sth{delete_list_data}->execute($list_id);
        $alive = 0;
    }
    my $out = "$list_id\0$alive";
    print $new_sock pack("nn", $msg_num{leave_list}, length($out));
    print $new_sock $out;
}

# update friend map
sub msg_add_friend
{
	my ($dbh, $sth_ref, $new_sock, $addr, $msg) = @_;
	my %sth = %$sth_ref;

	# device id followed by 1 or more friends numbers
	my ($device_id, $friend) = split("\0", $msg);

	return if (device_id_invalid($dbh, $sth_ref, $device_id, $addr));
	my $devid_fp = fingerprint($device_id);
	print "$addr: '$devid_fp' adding '$friend'\n";

	unless (looks_like_number($friend)) {
		print "$addr: bad friends number $friend\n";
		return;
	}

	# XXX: check they're not already a friend before doing this
	$sth{friends_map}->execute($device_id, $friend);

	# check if this added friend is a member already
	my ($fr_devid) = $dbh->selectrow_array($sth{ph_num_exists}, undef, $friend);
	if ($fr_devid) {
		print "$addr: added friend is a member\n";
		print "$addr: friends device id is '$fr_devid'\n";

		my $phnum = get_phone_number($dbh, $sth_ref, $device_id);

		# check if my phone number is in their friends list
		if ($dbh->selectrow_array($sth{friends_map_select}, undef, $fr_devid, $phnum)) {
			print "$addr: found mutual friendship\n";
			$sth{mutual_friend_insert}->execute($device_id, $fr_devid);
			$sth{mutual_friend_insert}->execute($fr_devid, $device_id);
		}
	}

	my $out = "$friend";
	print $new_sock pack("nn", $msg_num{add_friend}, length($out));
	print $new_sock $out;
}

sub msg_delete_friend
{
	my ($dbh, $sth_ref, $new_sock, $addr, $msg) = @_;

	# delete all friends, remove mutual friend references
	# $friends_map_delete_sth->execute($device_id);
	# $mutual_friends_delete_sth->execute($device_id, $device_id);
}

# get both lists the device is in, and lists it can see
sub msg_list_request
{
	my ($dbh, $sth_ref, $new_sock, $addr, $msg) = @_;
	my %sth = %$sth_ref;

	return if (device_id_invalid($dbh, $sth_ref, $msg, $addr));

	my $devid_fp = fingerprint($msg);
	print "info: $addr: gathering lists for '$devid_fp'\n";

	my @direct_lists;
    my @direct_list_ids;
	# first get all lists this device id is a direct member of
	$sth{get_lists}->execute($msg);
	while (my ($list_id, $list_name) = $sth{get_lists}->fetchrow_array()) {
		print "info: $addr: found list '$list_name' '$list_id'\n";

		# get all members of this list
		my @list_members;
		$sth{get_list_members}->execute($list_id);
		while (my ($member_device_id) = $sth{get_list_members}->fetchrow_array()) {
			push @list_members, get_phone_number($dbh, $sth_ref, $member_device_id);
			print "info: $addr: direct list: found member '$member_device_id'\n";
		}
        push @direct_list_ids, $list_id;
		push @direct_lists, "$list_name:$list_id:" . join(":", @list_members);
	}
	my $out .= join("\0", @direct_lists);

    # separator between direct/indirect lists
	$out .= "\0\0";

	my @indirect_lists;
	# now calculate which lists this device id should see
	$sth{mutual_friend_select}->execute($msg);
	while (my ($friend) = $sth{mutual_friend_select}->fetchrow_array()) {
		print "info: $addr: found mutual friend '$friend'\n";

		# get all of my friends lists
		$sth{get_lists}->execute($friend);

		# we can't send device id's back to the client
		my $friend_ph_num = get_phone_number($dbh, $sth_ref, $friend);

		while (my ($list_id, $list_name) =
			$sth{get_lists}->fetchrow_array()) {
            if (grep {$_ eq $list_id} @direct_list_ids) {
                next;
            }
		    print "info: $addr: found mutual friends list '$list_name'\n";

		    push @indirect_lists, "$list_name:$list_id:$friend_ph_num"
		}
	}
	$out .= join("\0", @indirect_lists);

	print $new_sock pack("nn", $msg_num{list_request}, length($out));
	print $new_sock $out;

	# XXX: add time of last request to list (rate throttling)?
}

sub msg_list_items
{
	my ($dbh, $sth_ref, $new_sock, $addr, $msg) = @_;
	my %sth = %$sth_ref;

	my ($device_id, $list_id) = split("\0", $msg);

	return if (device_id_invalid($dbh, $sth_ref, $device_id, $addr));

	if (!$list_id) {
		print "warn: $addr: received null list id";
		return;
	}
	unless ($dbh->selectrow_array($sth{check_list_member}, undef, $list_id, $device_id)) {
		# XXX: table list_members list_id's should always exist in table lists
		print "warn: $addr: $device_id not a member of $list_id\n";
		return;
	}
	print "info: $addr: $device_id request items for $list_id\n";

	$sth{get_list_items}->execute($list_id);

	my @items;
	while (my ($list_id, $pos, $name, $status, $owner, undef) =
		$sth{get_list_items}->fetchrow_array()) {
		print "info: $addr: list item #$pos $name\n";

		push @items, "$pos:$name:$owner:$status";
	}

	my $out = join("\0", @items);
	print $new_sock pack("nn", 6, length($out));
	print $new_sock $out;
}

sub msg_ok
{
	my ($dbh, $sth_ref, $new_sock, $addr, $msg) = @_;

	return if (device_id_invalid($dbh, $sth_ref, $msg, $addr));

	# send message type 8, 0 bytes payload
	print $new_sock pack("nn", 8, 1);
	print $new_sock '!';
}

sub fingerprint
{
	return substr shift, 0, 8;
}

sub device_id_invalid
{
	my ($dbh, $sth_ref, $device_id, $addr) = @_;

	# validate this at least looks like base64
	unless ($device_id =~ m/^[a-zA-Z0-9+\/=]+$/) {
		print "$addr: device id '$device_id' not valid base64\n";
		return 1;
	}

	# make sure we know about this device id
	unless ($dbh->selectrow_array($sth_ref->{device_id_exists}, undef, $device_id)) {
		print "$addr: unknown device '$device_id'\n";
		return 1;
	}

	return 0;
}

sub create_tables {

	my $db_handle = DBI->connect(
		"dbi:SQLite:dbname=$db_file",
		"", "",
		{ RaiseError => 1 }
	) or die $DBI::errstr;
	$db_handle->do("PRAGMA foreign_keys = ON");

	$db_handle->do(qq{create table if not exists lists(
		list_id int not null primary key,
		name text not null,
		first_created int not null,
		last_updated int not null)
	}) or die $DBI::errstr;

	$db_handle->do(qq{create table if not exists devices(
		device_id text not null primary key,
		phone_num int not null,
		type text,
		first_seen int not null)
	}) or die $DBI::errstr;

	$db_handle->do(qq{create table if not exists friends_map(
		device_id text not null,
		friend int not null,
		primary key(device_id, friend),
		foreign key(device_id) references devices(device_id))
	}) or die $DBI::errstr;

	$db_handle->do(qq{create table if not exists mutual_friends(
		device_id text not null,
		mutual_friend text not null,
		primary key(device_id, mutual_friend),
		foreign key(device_id) references devices(device_id),
		foreign key(mutual_friend) references devices(device_id))
	}) or die $DBI::errstr;

	$db_handle->do(qq{create table if not exists list_members(
		list_id int not null,
		device_id text not null,
		joined_date int not null,
		primary key(list_id, device_id),
		foreign key(list_id) references lists(list_id),
		foreign key(device_id) references devices(device_id))
	}) or die $DBI::errstr;

	$db_handle->do(qq{create table if not exists list_data(
		list_id int not null,
		name text not null,
		quantity non null,
		status int not null default 0,
		owner text not null,
		last_updated int not null,
		primary key(list_id, name, owner),
		foreign key(list_id) references lists(list_id),
		foreign key(owner) references devices(device_id))
	}) or die $DBI::errstr;

	$db_handle->disconnect();
	$db_handle = undef;
}

sub prepare_stmt_handles {
	my $dbh = shift;

	my %stmt_handles;
	my $sql;

	# list table queries
	$sql = qq{insert into lists (list_id, name, first_created, last_updated)
	values (?, ?, ?, ?)};
	$stmt_handles{new_list} = $dbh->prepare($sql);

	$sql = qq{delete from lists where list_id = ?};
	$stmt_handles{delete_list} = $dbh->prepare($sql);

	# devices table queries
	$sql = qq{insert into devices (device_id, phone_num, first_seen) values (?, ?, ?)};
	$stmt_handles{new_device} = $dbh->prepare($sql);

	$sql = qq{select * from devices where phone_num = ?};
	$stmt_handles{ph_num_exists} = $dbh->prepare($sql);

	$sql = qq{select * from devices where device_id = ?};
	$stmt_handles{device_id_exists} = $dbh->prepare($sql);

	# friends_map table queries
	$sql = qq{insert into friends_map (device_id, friend) values (?, ?)};
	$stmt_handles{friends_map} = $dbh->prepare($sql);

	$sql = qq{select * from friends_map where device_id = ? and friend = ?};
	$stmt_handles{friends_map_select} = $dbh->prepare($sql);

	$sql = qq{delete from friends_map where device_id = ?};
	$stmt_handles{friends_map_delete} = $dbh->prepare($sql);

	# mutual_friends table
	$sql = qq{insert into mutual_friends (device_id, mutual_friend) values (?, ?)};
	$stmt_handles{mutual_friend_insert} = $dbh->prepare($sql);

	$sql = qq{select mutual_friend from mutual_friends where device_id = ?};
	$stmt_handles{mutual_friend_select} = $dbh->prepare($sql);

	$sql = qq{delete from mutual_friends where device_id = ? or mutual_friend = ?};
	$stmt_handles{mutual_friends_delete} = $dbh->prepare($sql);

	# lists/list_members compound queries
	$sql = qq{select lists.list_id, lists.name from lists, list_members where
	lists.list_id = list_members.list_id and device_id = ?};
	$stmt_handles{get_lists} = $dbh->prepare($sql);

	# list_members table
	$sql = qq{select device_id from list_members where list_id = ?};
	$stmt_handles{get_list_members} = $dbh->prepare($sql);

	$sql = qq{insert into list_members (list_id, device_id, joined_date) values (?, ?, ?)};
	$stmt_handles{new_list_member} = $dbh->prepare($sql);

	$sql = qq{delete from list_members where list_id = ? and device_id = ?};
	$stmt_handles{remove_list_member} = $dbh->prepare($sql);

	$sql = qq{select device_id from list_members where list_id = ? and device_id = ?};
	$stmt_handles{check_list_member} = $dbh->prepare($sql);

	# list_data table
	$sql = qq{delete from list_data where list_id = ?};
	$stmt_handles{delete_list_data} = $dbh->prepare($sql);

	$sql = qq{select * from list_data where list_id = ?};
	$stmt_handles{get_list_items} = $dbh->prepare($sql);

	$sql = qq{insert into list_data (list_id, name, quantity, status, owner, last_updated) values (?, ?, ?, ?, ?, ?)};
	$stmt_handles{new_list_item} = $dbh->prepare($sql);

	return \%stmt_handles;
}

sub error {
	return if ($LOG_LEVEL < $LOG_LEVEL_ERROR);
	print "error: " . sprintf @_;
}

sub warn {
	return if ($LOG_LEVEL < $LOG_LEVEL_WARN);
	print "warn: " . sprintf @_;
}

sub info {
	return if ($LOG_LEVEL < $LOG_LEVEL_INFO);
	print "info: " . sprintf @_;
}

sub debug {
	return if ($LOG_LEVEL < $LOG_LEVEL_DEBUG);
	print "debug: " . sprintf @_;
}
