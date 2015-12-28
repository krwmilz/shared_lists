#!/usr/bin/perl -I.
use warnings;
use strict;

use BSD::arc4random qw(:all);
use DBI;
use File::Temp;
use Digest::SHA qw(sha256_base64);
use Getopt::Std;
use IO::Socket::SSL;
use POSIX;
use Scalar::Util qw(looks_like_number);

require "msgs.pl";
our (%msg_num, @msg_str, @msg_func, $protocol_ver);

my %args;
getopts("p:t", \%args);

$SIG{TERM} = sub { exit };

my $db_file = "db";
# EXLOCK needs to be 0 because SQLite expects it to be
$db_file = File::Temp->new(SUFFIX => '.db', EXLOCK => 0) if ($args{t});

log_print_bare("creating new database '$db_file'\n") unless (-e $db_file);
create_tables();

my $listen_sock = new IO::Socket::INET (
	LocalHost => '0.0.0.0',
	LocalPort => $args{p} || '5437',
	Proto => 'tcp',
	Listen => 100,
	Reuse => 1,
);
die "Could not create socket: $!\n" unless $listen_sock;

my ($laddr, $lport) = ($listen_sock->sockhost(), $listen_sock->sockport());
log_print_bare("accepting connections on $laddr:$lport (pid = '$$')\n");

while (my $new_sock = $listen_sock->accept()) {

	# create a child process to handle this client
	my $pid = fork;
	if (!defined $pid) {
		die "error: can't fork: $!\n";
	} elsif ($pid) {
		# in parent: go back to listening for more connections
		close $new_sock;
		next;
	}

	close $listen_sock;
	log_set_peer_host_port($new_sock);
	log_print("new connection (pid = '$$')\n");

	# upgrade connection to SSL
	IO::Socket::SSL->start_SSL($new_sock,
		SSL_server => 1,
		SSL_cert_file => 'ssl/cert_chain.pem',
		SSL_key_file => 'ssl/privkey.pem'
	) or die "failed to ssl handshake: $SSL_ERROR";
	my $ssl_ver = $new_sock->get_sslversion();
	my $ssl_cipher = $new_sock->get_cipher();
	log_print("ssl started, ver = '$ssl_ver' cipher = '$ssl_cipher'\n");

	# each child opens their own database connection
	my $dbh = DBI->connect(
		"dbi:SQLite:dbname=$db_file",
		"", "",
		{ RaiseError => 1 }
	) or die $DBI::errstr;

	$dbh->do("PRAGMA foreign_keys = ON");
	$dbh->{AutoCommit} = 1;
	my $stmt_handles = prepare_stmt_handles($dbh);

	# main message receiving loop
	while (1) {
		my ($msg_type, $msg) = recv_msg($new_sock);
		last unless (defined $msg_type && defined $msg);

		$dbh->begin_work;
		my $reply = $msg_func[$msg_type]->($dbh, $stmt_handles, $msg);
		$dbh->commit;

		if ($@) {
			warn "Transaction aborted because $@";
			# now rollback to undo the incomplete changes
			# but do it in an eval{} as it may also fail
			eval { $dbh->rollback };
			# XXX: are database errors fatal to this connection?
			next;
		}

		# when message handlers have errors, don't send a reply
		next unless defined $reply;
		send_msg($new_sock, $msg_type, $reply);
	}

	$stmt_handles->{$_} = undef for (keys %$stmt_handles);
	$dbh->disconnect();

	log_print("disconnected!\n");
	exit 0;
}
print "got here\n";

# any header parsing errors or message read errors are fatal in this function
sub recv_msg {
	my ($sock) = (@_);

	my $header = read_all($sock, 4);
	return undef unless defined $header;

	my ($msg_type, $msg_size) = unpack("nn", $header);
	unless (defined $msg_type && defined $msg_size) {
		log_print("error: unpacking message type or size\n");
		return undef;
	}

	if ($msg_type >= @msg_str) {
		my $bad_msg = sprintf "0x%x", $msg_type;
		log_print("error: unknown message type $bad_msg\n");
		return undef;
	}

	if ($msg_size > 4096) {
		log_print("error: $msg_size byte message too large\n");
		return undef;
	}
	elsif ($msg_size == 0) {
		# don't try and do another read, as a read of size 0 is EOF
		return ($msg_type, "");
	}

	my $msg = read_all($sock, $msg_size);
	return undef unless defined $msg;

	return ($msg_type, $msg);
}

sub read_all {
	my ($sock, $bytes_total) = @_;

	my $bytes_read = $sock->sysread(my $data, $bytes_total);
	if (!defined $bytes_read) {
		log_print("error: read failed: $!\n");
		return undef;
	} elsif ($bytes_read == 0) {
		# log_print("error: read EOF\n");
		return undef;
	} elsif ($bytes_read != $bytes_total) {
		log_print("error: read $bytes_read instead of $bytes_total bytes\n");
		return undef;
	}

	return $data;
}

sub send_msg {
	my ($socket, $msg_type, $msg) = (@_);

	my $n = $socket->syswrite(pack("nn", $msg_type, length($msg)));
	$n += $socket->syswrite($msg);
	return $n;
}

sub get_phone_number
{
	my ($dbh, $sth, $device_id) = @_;

	#print "info: get_phone_number() unimplemented, returning device id!\n";
	#return $device_id;
	my (undef, $ph_num) = $dbh->selectrow_array($sth->{device_id_exists}, undef, $device_id);
	unless (defined $ph_num && looks_like_number($ph_num)) {
		log_print("phone number lookup for $device_id failed!\n");
		return "000";
	}

	return $ph_num;
}

sub msg_new_device
{
	my ($dbh, $sth_ref, $msg) = @_;
	my %sth = %$sth_ref;

	# single field
	my $ph_num = $msg;

	if (!looks_like_number($ph_num)) {
		log_print("new_device: received phone number '$ph_num' invalid\n");
		return;
	}
	if ($dbh->selectrow_array($sth{ph_num_exists}, undef, $ph_num)) {
		log_print("new_device: phone number '$ph_num' already exists\n");
		return;
	}

	# make a new device id, the client will supply this on all
	# further communication
	# XXX: need to check the db to make sure this isn't duplicate
	my $token = sha256_base64(arc4random_bytes(32));

	$sth{new_device}->execute($token, $ph_num, time);
	log_print("new_device: success '$ph_num' '" .fingerprint($token). "'\n");

	return $token;
}

sub msg_new_list
{
	my ($dbh, $sth_ref, $msg) = @_;
	my %sth = %$sth_ref;

	# expecting two fields delimited by null
	my ($device_id, $list_name) = split("\0", $msg);

	# validate input
	return if (device_id_invalid($dbh, $sth_ref, $device_id));
	unless ($list_name) {
		log_print("new_list: name field missing\n");
		return;
	}
	my $devid_fp = fingerprint($device_id);

	log_print("new_list: '$list_name'\n");
	log_print("new_list: adding first member devid = '$devid_fp'\n");

	my $time = time;
	my $list_id = sha256_base64(arc4random_bytes(32));
	log_print("new_list: fingerprint = '" .fingerprint($list_id). "'\n");

	# add new list with single list member
	$sth{new_list}->execute($list_id, $list_name, $time, $time);
	$sth{new_list_member}->execute($list_id, $device_id, $time);

	# XXX: also send back the date and all that stuff
	my $phone_number = get_phone_number($dbh, $sth_ref, $device_id);
	my $out = $list_id . "\0" . $list_name . "\0" . $phone_number;

	return $out;
}

sub msg_new_list_item
{
    my ($dbh, $sth_ref, $new_sock, $msg) = @_;
    return undef;

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
    my ($dbh, $sth_ref, $msg) = @_;
    my %sth = %$sth_ref;
    my ($device_id, $list_id) = split("\0", $msg);

    return if (device_id_invalid($dbh, $sth_ref, $device_id));

    log_print("join_list: device '$device_id'\n");
    log_print("join_list: list '$list_id'\n");
    
    my $time = time;
    $sth{check_list_member}->execute($list_id, $device_id);

    if (!$sth{check_list_member}->fetchrow_array()) {
        $sth{new_list_member}->execute($list_id, $device_id, $time);
        log_print("join_list: device '$device_id' has been added to list '$list_id'\n");
    } else {
        log_print("join_list: tried to create a duplicate list member entry for device $device_id and list $list_id\n");
    }

    return $list_id;
}

sub msg_leave_list
{
    my ($dbh, $sth_ref, $msg) = @_;
    my %sth = %$sth_ref;

    my ($device_id, $list_id) = split("\0", $msg);

    return if (device_id_invalid($dbh, $sth_ref, $device_id));
    
    log_print("leave_list: device '$device_id'\n");
    log_print("leave_list: list '$list_id'\n");

    $sth{check_list_member}->execute($list_id, $device_id);

    if ($sth{check_list_member}->fetchrow_array()) {
        $sth{remove_list_member}->execute($list_id, $device_id);
        log_print("leave_list: device '$device_id' has been removed from list '$list_id'\n");
    } else {
        log_print("leave_list: warn: tried to leave a list the user was not in for device '$device_id' and list '$list_id'\n");
    }
    $sth{check_list_member}->finish();

    $sth{get_list_members}->execute($list_id);
    
    my $alive = 1;

    if (!$sth{get_list_members}->fetchrow_array()) {
        log_print("leave_list: list '$list_id' is empty... deleting\n");
        $sth{delete_list}->execute($list_id);
        $sth{delete_list_data}->execute($list_id);
        $alive = 0;
    }
    my $out = "$list_id\0$alive";

    return $out;
}

# update friend map
sub msg_add_friend
{
	my ($dbh, $sth_ref, $msg) = @_;
	my %sth = %$sth_ref;

	# device id followed by 1 friends number
	my ($device_id, $friend) = split("\0", $msg);

	return if (device_id_invalid($dbh, $sth_ref, $device_id));
	my $devid_fp = fingerprint($device_id);
	log_print("add_friend: '$devid_fp' adding '$friend'\n");

	unless (looks_like_number($friend)) {
		log_print("add_friend: bad friends number '$friend'\n");
		return;
	}

	# XXX: check they're not already a friend before doing this
	$sth{friends_map}->execute($device_id, $friend);

	# check if this added friend is a member already
	my ($fr_devid) = $dbh->selectrow_array($sth{ph_num_exists}, undef, $friend);
	if ($fr_devid) {
		my $friends_fp = fingerprint($fr_devid);
		log_print("add_friend: added friend is a member\n");
		log_print("add_friend: friends device id is '$friends_fp'\n");

		my $phnum = get_phone_number($dbh, $sth_ref, $device_id);

		# check if my phone number is in their friends list
		if ($dbh->selectrow_array($sth{friends_map_select}, undef, $fr_devid, $phnum)) {
			log_print("add_friend: found mutual friendship\n");
			$sth{mutual_friend_insert}->execute($device_id, $fr_devid);
			$sth{mutual_friend_insert}->execute($fr_devid, $device_id);
		}
	}

	return $friend;
}

sub msg_delete_friend
{
	my ($dbh, $sth_ref, $new_sock, $msg) = @_;

	# delete all friends, remove mutual friend references
	# $friends_map_delete_sth->execute($device_id);
	# $mutual_friends_delete_sth->execute($device_id, $device_id);
}

# get both lists the device is in, and lists it can see
sub msg_list_request
{
	my ($dbh, $sth_ref, $msg) = @_;
	my %sth = %$sth_ref;

	return if (device_id_invalid($dbh, $sth_ref, $msg));

	my $devid_fp = fingerprint($msg);
	log_print("list_request: gathering lists for '$devid_fp'\n");

	my @direct_lists;
    my @direct_list_ids;
	# first get all lists this device id is a direct member of
	$sth{get_lists}->execute($msg);
	while (my ($list_id, $list_name) = $sth{get_lists}->fetchrow_array()) {
		log_print("list_request: found list '$list_name' '$list_id'\n");

		# get all members of this list
		my @list_members;
		$sth{get_list_members}->execute($list_id);
		while (my ($member_device_id) = $sth{get_list_members}->fetchrow_array()) {
			push @list_members, get_phone_number($dbh, $sth_ref, $member_device_id);
			log_print("list_request: direct list: found member '$member_device_id'\n");
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
		log_print("list_request: found mutual friend '$friend'\n");

		# get all of my friends lists
		$sth{get_lists}->execute($friend);

		# we can't send device id's back to the client
		my $friend_ph_num = get_phone_number($dbh, $sth_ref, $friend);

		while (my ($list_id, $list_name) =
			$sth{get_lists}->fetchrow_array()) {
            if (grep {$_ eq $list_id} @direct_list_ids) {
                next;
            }
		    log_print("list_request: found mutual friends list '$list_name'\n");

		    push @indirect_lists, "$list_name:$list_id:$friend_ph_num"
		}
	}
	$out .= join("\0", @indirect_lists);

	return $out;

	# XXX: add time of last request to list (rate throttling)?
}

sub msg_list_items
{
	my ($dbh, $sth_ref, $msg) = @_;
	my %sth = %$sth_ref;

	my ($device_id, $list_id) = split("\0", $msg);

	return if (device_id_invalid($dbh, $sth_ref, $device_id));

	if (!$list_id) {
		log_print("list_items: received null list id");
		return;
	}
	unless ($dbh->selectrow_array($sth{check_list_member}, undef, $list_id, $device_id)) {
		# XXX: table list_members list_id's should always exist in table lists
		log_print("list_items: $device_id not a member of $list_id\n");
		return;
	}
	log_print("list_items: $device_id request items for $list_id\n");

	$sth{get_list_items}->execute($list_id);

	my @items;
	while (my ($list_id, $pos, $name, $status, $owner, undef) =
		$sth{get_list_items}->fetchrow_array()) {
		log_print("list_items: list item #$pos $name\n");

		push @items, "$pos:$name:$owner:$status";
	}

	my $out = join("\0", @items);
	return $out;
}

sub msg_ok
{
	my ($dbh, $sth_ref, $msg) = @_;

	return if (device_id_invalid($dbh, $sth_ref, $msg));

	log_print("ok: device '" . fingerprint($msg) . "' checking in\n");

	# send empty payload back
	return "";
}

sub fingerprint
{
	return substr shift, 0, 8;
}

sub device_id_invalid
{
	my ($dbh, $sth_ref, $device_id) = @_;

	unless ($device_id) {
		log_print("device id '' invalid\n");
		return 1;
	}

	# validate this at least looks like base64
	unless ($device_id =~ m/^[a-zA-Z0-9+\/=]+$/) {
		log_print("device id '$device_id' not valid base64\n");
		return 1;
	}

	# make sure we know about this device id
	unless ($dbh->selectrow_array($sth_ref->{device_id_exists}, undef, $device_id)) {
		log_print("unknown device '$device_id'\n");
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

my ($addr, $port) = ('', '');
sub log_set_peer_host_port {
	my ($sock) = (@_);
	($addr, $port) = ($sock->peerhost(), $sock->peerport());
}

sub log_print {
	my $ftime = strftime("%F %T", localtime);
	printf "%s %-15s %-5s> ", $ftime, $addr, $port;
	# we print potentially unsafe strings here, don't use printf
	print @_;
}

sub log_print_bare {
	my $ftime = strftime("%F %T", localtime);
	printf "%s> ", $ftime;
	printf @_;
}
