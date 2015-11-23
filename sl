#!/usr/bin/perl -w
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
# -p is port, -t is use temporary in memory db
getopts("p:t", \%args);

my $db_file = "db";
if ($args{t}) {
	$db_file = ":memory:";
}
elsif (! -e $db_file) {
	print "info: creating new database '$db_file'\n";
}

my $parent_dbh = DBI->connect(
	"dbi:SQLite:dbname=$db_file",
	"",
	"",
	{ RaiseError => 1 }
) or die $DBI::errstr;

# our transaction scheme needs for this to be on
$parent_dbh->{AutoCommit} = 1;
$parent_dbh->do("PRAGMA foreign_keys = ON");

# create any new tables, if needed
create_tables($parent_dbh);

# list table queries
my $sql = qq{insert into lists (list_id, name, first_created, last_updated)
	values (?, ?, ?, ?)};
my $new_list_sth = $parent_dbh->prepare($sql);

$sql = qq{delete from lists where list_id = ?};
my $delete_list_sth = $parent_dbh->prepare($sql);


# devices table queries
$sql = qq{insert into devices (device_id, phone_num, first_seen) values (?, ?, ?)};
my $new_device_sth = $parent_dbh->prepare($sql);

$sql = qq{select * from devices where phone_num = ?};
my $ph_num_exists_sth = $parent_dbh->prepare($sql);

$sql = qq{select * from devices where device_id = ?};
my $device_id_exists_sth = $parent_dbh->prepare($sql);


# friends_map table queries
$sql = qq{insert into friends_map (device_id, friend) values (?, ?)};
my $friends_map_sth = $parent_dbh->prepare($sql);

$sql = qq{select friend from friends_map where device_id = ?};
my $friends_map_select_sth = $parent_dbh->prepare($sql);

$sql = qq{delete from friends_map where device_id = ?};
my $friends_map_delete_sth = $parent_dbh->prepare($sql);


# mutual_friends table
$sql = qq{select mutual_friend from mutual_friends where device_id = ?};
my $mutual_friend_select_sth = $parent_dbh->prepare($sql);

$sql = qq{delete from mutual_friends where device_id = ? or mutual_friend = ?};
my $mutual_friends_delete_sth = $parent_dbh->prepare($sql);


# lists/list_members compound queries
$sql = qq{select lists.list_id, lists.name from lists, list_members where
	lists.list_id = list_members.list_id and device_id = ?};
my $get_lists_sth = $parent_dbh->prepare($sql);


# list_members table
$sql = qq{select device_id from list_members where list_id = ?};
my $get_list_members_sth = $parent_dbh->prepare($sql);

$sql = qq{insert into list_members (list_id, device_id, joined_date) values (?, ?, ?)};
my $new_list_member_sth = $parent_dbh->prepare($sql);

$sql = qq{delete from list_members where list_id = ? and device_id = ?};
my $remove_list_member_sth = $parent_dbh->prepare($sql);

$sql = qq{select device_id from list_members where list_id = ? and device_id = ?};
my $check_list_member_sth = $parent_dbh->prepare($sql);


# list_data table
$sql = qq{delete from list_data where list_id = ?};
my $delete_list_data_sth = $parent_dbh->prepare($sql);

$sql = qq{select * from list_data where list_id = ?};
my $get_list_items_sth = $parent_dbh->prepare($sql);

$sql = qq{insert into list_data (list_id, name, quantity, status, owner, last_updated) values (?, ?, ?, ?, ?, ?)};
my $new_list_item_sth = $parent_dbh->prepare($sql);

my $done = 0;

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
$SIG{INT} = \&sig_handler;
$SIG{TERM} = \&sig_handler;
sub sig_handler {
	wait;
	$parent_dbh->disconnect();
	$parent_dbh = undef;
	$sock->shutdown(SHUT_RDWR);
	close($sock);
	$done = 1;
}

while (!$done) {
	my ($new_sock, $bin_addr) = $sock->accept();
	if (!$new_sock) {
		# print "warn: accepted empty socket";
		next;
	}

	my $pid = fork();
	die "error: can't fork: $!\n" if (!defined $pid);

	if ($pid) {
		# parent goes back to listening for more connections
		close $new_sock;
		# print "parent: forked child $pid\n";
		next;
	}

	$SIG{INT} = 'IGNORE';
	$SIG{TERM} = 'IGNORE';

	# after here we know we're in the child
	# supposed to do this for db connections across forks
	my $child_dbh = $parent_dbh->clone();
	$child_dbh->{AutoCommit} = 1;

	# afaict unreferences the parents db handle
	$parent_dbh->{InactiveDestroy} = 1;
	undef $parent_dbh;

	# NI_NUMERIC* mean don't try and resolve ip address or port
	my ($err, $addr, $port) = getnameinfo($bin_addr, NI_NUMERICHOST | NI_NUMERICSERV);
	print "warn: getnameinfo() failed: $err\n" if ($err);
	$addr = sprintf "%s [%5s] %15s/%5i", strftime("%F %T", localtime), $$, $addr, $port;
	print "$addr: new connection\n";

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

		$child_dbh->begin_work;
		# call the appropriate handler
		$msg_func[$msg_type]->($child_dbh, $new_sock, $addr." $msg_str[$msg_type]", $msg);

		$child_dbh->commit;   # commit the changes if we get this far
		if ($@) {
			warn "Transaction aborted because $@";
			# now rollback to undo the incomplete changes
			# but do it in an eval{} as it may also fail
			eval { $child_dbh->rollback };
			# add other application on-error-clean-up code here
		}
	}

	print "$addr: disconnected!\n";
	$new_sock->shutdown(SHUT_RDWR);
	close($new_sock);
	$child_dbh->disconnect();
	$child_dbh = undef;

	exit 0;
}

sub get_phone_number
{
	my ($dbh, $device_id) = @_;

	#print "info: get_phone_number() unimplemented, returning device id!\n";
	#return $device_id;
	my (undef, $ph_num) = $dbh->selectrow_array($device_id_exists_sth, undef, $device_id);
	unless (defined $ph_num && looks_like_number($ph_num)) {
		print "warn: phone number lookup for $device_id failed!\n";
		return "000";
	}

	return $ph_num;
}

sub msg_new_device
{
	my ($dbh, $new_sock, $addr, $msg) = @_;

	# single field
	my $ph_num = $msg;

	if (!looks_like_number($ph_num)) {
		print "$addr: device phone number $ph_num invalid\n";
		return;
	}
	if ($dbh->selectrow_array($ph_num_exists_sth, undef, $ph_num)) {
		print "$addr: phone number $ph_num already exists\n";
		return;
	}

	# make a new device id, the client will supply this on all
	# further communication
	# XXX: need to check the db to make sure this isn't duplicate
	my $token = sha256_base64(arc4random_bytes(32));

	print $new_sock pack("nn", 0, length($token));
	print $new_sock $token;
	$new_device_sth->execute($token, $ph_num, time);
	print "$addr: added new device '$ph_num' '" .fingerprint($token). "'\n";
}

sub msg_new_list
{
	my ($dbh, $new_sock, $addr, $msg) = @_;

	# expecting two fields delimited by null
	my ($device_id, $list_name) = split("\0", $msg);

	# validate input
	return if (device_id_invalid($dbh, $device_id, $addr));
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
	$new_list_sth->execute($list_id, $list_name, $time, $time);
	$new_list_member_sth->execute($list_id, $device_id, $time);

	# XXX: also send back the date and all that stuff
	my $phone_number = get_phone_number($dbh, $device_id);
	my $out = $list_id . "\0" . $list_name . "\0" . $phone_number;
	print $new_sock pack("nn", 1, length($out));
	print $new_sock $out;
}

sub msg_new_list_item
{
    my ($dbh, $new_sock, $addr, $msg) = @_;

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
    my ($dbh, $new_sock, $addr, $msg) = @_;
    my ($device_id, $list_id) = split("\0", $msg);

    return if (device_id_invalid($dbh, $device_id, $addr));

    print "info: $addr: device $device_id\n";
    print "info: $addr: list $list_id\n";
    
    my $time = time;
    $check_list_member_sth->execute($list_id, $device_id);

    if (!$check_list_member_sth->fetchrow_array()) {
        $new_list_member_sth->execute($list_id, $device_id, $time);
        print "info: $addr: device $device_id has been added to list $list_id\n";
    } else {
        print "warn: $addr: tried to create a duplicate list member entry for device $device_id and list $list_id\n";
    }

    print $new_sock pack("nn", 4, length($list_id));
    print $new_sock $list_id;
}

sub msg_leave_list
{
    my ($dbh, $new_sock, $addr, $msg) = @_;

    my ($device_id, $list_id) = split("\0", $msg);

    return if (device_id_invalid($dbh, $device_id, $addr));
    
    print "info: $addr: device $device_id\n";
    print "info: $addr: list $list_id\n";

    $check_list_member_sth->execute($list_id, $device_id);

    if ($check_list_member_sth->fetchrow_array()) {
        $remove_list_member_sth->execute($list_id, $device_id);
        print "info: $addr: device $device_id has been removed from list $list_id\n";
    } else {
        print "warn: $addr: tried to leave a list the user was not in for device $device_id and list $list_id\n";
    }

    $get_list_members_sth->execute($list_id);
    
    my $alive = 1;

    if (!$get_list_members_sth->fetchrow_array()) {
        print "info: $addr: list $list_id is empty... deleting\n";
        $delete_list_sth->execute($list_id);
        $delete_list_data_sth->execute($list_id);
        $alive = 0;
    }
    my $out = "$list_id\0$alive";
    print $new_sock pack("nn", 5, length($out));
    print $new_sock $out;
}

# update friend map
sub msg_add_friend
{
	my ($dbh, $new_sock, $addr, $msg) = @_;

	# device id followed by 1 or more friends numbers
	my ($device_id, $friend) = split("\0", $msg);

	return if (device_id_invalid($dbh, $device_id, $addr));
	print "$addr: '$device_id' adding '$friend'\n";

	unless (looks_like_number($friend)) {
		print "$addr: bad friends number $friend\n";
		return;
	}

	# $friends_map_sth->execute($device_id, $_);
	# print "$addr: added friend $_\n";

	my $out = "$friend";
	print $new_sock pack("nn", $msg_num{add_friend}, length($out));
	print $new_sock $out;
}

sub msg_delete_friend
{
	my ($dbh, $new_sock, $addr, $msg) = @_;

	# delete all friends, remove mutual friend references
	# $friends_map_delete_sth->execute($device_id);
	# $mutual_friends_delete_sth->execute($device_id, $device_id);
}

# get both lists the device is in, and lists it can see
sub msg_list_request
{
	my ($dbh, $new_sock, $addr, $msg) = @_;

	return if (device_id_invalid($dbh, $msg, $addr));

	my $devid_fp = fingerprint($msg);
	print "info: $addr: gathering lists for '$devid_fp'\n";

	my @direct_lists;
    my @direct_list_ids;
	# first get all lists this device id is a direct member of
	$get_lists_sth->execute($msg);
	while (my ($list_id, $list_name) = $get_lists_sth->fetchrow_array()) {
		print "info: $addr: found list '$list_name' '$list_id'\n";

		# get all members of this list
		my @list_members;
		$get_list_members_sth->execute($list_id);
		while (my ($member_device_id) = $get_list_members_sth->fetchrow_array()) {
			push @list_members, get_phone_number($dbh, $member_device_id);
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
	$mutual_friend_select_sth->execute($msg);
	while (my ($friend) = $mutual_friend_select_sth->fetchrow_array()) {
		print "info: $addr: found mutual friend $friend\n";

		# get all of my friends lists
		$get_lists_sth->execute($friend);

		# we can't send device id's back to the client
		my $friend_ph_num = get_phone_number($dbh, $friend);

		while (my ($list_id, $list_name) =
			$get_lists_sth->fetchrow_array()) {
            if ($list_id ~~ @direct_list_ids) {
                next;
            }
		    print "info: $addr: found mutual friends list '$list_name'\n";

		    push @indirect_lists, "$list_name:$list_id:$friend_ph_num"
		}
	}
	$out .= join("\0", @indirect_lists);

	print $new_sock pack("nn", 3, length($out));
	print $new_sock $out;

	# XXX: add time of last request to list (rate throttling)?
}

sub msg_list_items
{
	my ($dbh, $new_sock, $addr, $msg) = @_;

	my ($device_id, $list_id) = split("\0", $msg);

	return if (device_id_invalid($dbh, $device_id, $addr));

	if (!$list_id) {
		print "warn: $addr: received null list id";
		return;
	}
	unless ($dbh->selectrow_array($check_list_member_sth, undef, $list_id, $device_id)) {
		# XXX: table list_members list_id's should always exist in table lists
		print "warn: $addr: $device_id not a member of $list_id\n";
		return;
	}
	print "info: $addr: $device_id request items for $list_id\n";

	$get_list_items_sth->execute($list_id);

	my @items;
	while (my ($list_id, $pos, $name, $status, $owner, undef) =
		$get_list_items_sth->fetchrow_array()) {
		print "info: $addr: list item #$pos $name\n";

		push @items, "$pos:$name:$owner:$status";
	}

	my $out = join("\0", @items);
	print $new_sock pack("nn", 6, length($out));
	print $new_sock $out;
}

sub msg_ok
{
	my ($dbh, $new_sock, $addr, $msg) = @_;

	return if (device_id_invalid($dbh, $msg, $addr));

	# send message type 8, 0 bytes payload
	print $new_sock pack("nn", 8, 1);
	print $new_sock '!';
}

sub fingerprint
{
	my $device_id = shift;
	return substr $device_id, 0, 8;
}

sub device_id_invalid
{
	my ($dbh, $device_id, $addr) = @_;

	# validate this at least looks like base64
	unless ($device_id =~ m/^[a-zA-Z0-9+\/=]+$/) {
		print "$addr: device id '$device_id' not valid base64\n";
		return 1;
	}

	# make sure we know about this device id
	unless ($dbh->selectrow_array($device_id_exists_sth, undef, $device_id)) {
		print "$addr: unknown device '$device_id'\n";
		return 1;
	}

	return 0;
}

sub create_tables {

	my $db_handle = shift;

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
		foreign key(device_id) references devices(device_id))
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
