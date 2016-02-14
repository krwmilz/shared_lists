package database;

use DBI;
use File::Temp;

sub new {
	my $class = shift;
	my $db_file = shift;

	my $self = {};
	bless ($self, $class);

	$self->{dbh} = DBI->connect(
		"dbi:SQLite:dbname=$db_file",
		"", "",
		{
			RaiseError => 1,
			sqlite_unicode => 1,
		}
	) or die $DBI::errstr;

	$self->{dbh}->do("PRAGMA foreign_keys = ON");
	$self->{dbh}->{AutoCommit} = 1;

	return $self;
}

sub create_tables {
	my ($self) = @_;

	my $db_handle = $self->{dbh};
	$db_handle->begin_work;

	$db_handle->do(qq{
		create table if not exists lists (
		num integer primary key,
		name text not null,
		date int,
		created int not null,
		last_updated int not null)
	});

	$db_handle->do(qq{
		create table if not exists devices (
		num integer primary key,
		id text not null,
		phone_num text not null,
		os text,
		push_token text,
		seen_first int not null,
		seen_last int not null)
	});

	$db_handle->do(qq{
		create table if not exists friends (
		device integer not null,
		friend text not null,
		primary key(device, friend),
		foreign key(device) references devices(num))
	});

	$db_handle->do(qq{
		create table if not exists mutual_friends (
		device integer not null,
		mutual_friend integer not null,
		primary key(device, mutual_friend),
		foreign key(device) references devices(num),
		foreign key(mutual_friend) references devices(num))
	});

	$db_handle->do(qq{
		create table if not exists list_members (
		list integer,
		device integer,
		joined int not null,
		primary key(list, device),
		foreign key(list) references lists(num),
		foreign key(device) references devices(num))
	});

	$db_handle->do(qq{
		create table if not exists list_data (
		num integer primary key,
		list integer,
		name text,
		owner integer,
		status int not null default 0,
		quantity,
		created int not null,
		last_updated int not null,
		foreign key(list) references lists(num),
		foreign key(owner) references devices(num))
	});

	$db_handle->commit;
	$self->{dbh}->disconnect();
	$self->{dbh} = undef;
}

sub prepare_stmt_handles {
	my ($self) = @_;

	my $dbh = $self->{dbh};
	my $sql;

	# list table queries
	$sql = 'select * from lists where num = ?';
	$self->{list_select} = $dbh->prepare($sql);

	$sql = 'insert into lists (name, date, created, last_updated) values (?, ?, ?, ?)';
	$self->{new_list} = $dbh->prepare($sql);

	$sql = qq{update lists set name = coalesce(?, name),
		date = coalesce(?, date), last_updated = ? where num = ?};
	$self->{update_list} = $dbh->prepare($sql);

	$sql = 'delete from lists where num = ?';
	$self->{delete_list} = $dbh->prepare($sql);

	# devices table queries
	$sql = 'insert into devices (id, phone_num, os, push_token, seen_first, seen_last) values (?, ?, ?, ?, ?, ?)';
	$self->{new_device} = $dbh->prepare($sql);

	$sql = 'select * from devices where phone_num = ?';
	$self->{ph_num_exists} = $dbh->prepare($sql);

	$sql = 'select * from devices where id = ?';
	$self->{select_device_id} = $dbh->prepare($sql);

	$sql = 'update devices set push_token = coalesce(?, push_token) where num = ?';
	$self->{update_device} = $dbh->prepare($sql);

	# friends table queries
	$sql = 'insert or replace into friends (device, friend) values (?, ?)';
	$self->{friends_insert} = $dbh->prepare($sql);

	$sql = 'select * from friends where device = ? and friend = ?';
	$self->{friends_select} = $dbh->prepare($sql);

	$sql = 'delete from friends where device = ? and friend = ?';
	$self->{friends_delete} = $dbh->prepare($sql);

	# mutual_friends table queries
	$sql = 'insert or replace into mutual_friends (device, mutual_friend) values (?, ?)';
	$self->{mutual_friend_insert} = $dbh->prepare($sql);

	$sql = qq{select devices.num, devices.phone_num, devices.os, devices.push_token
		from devices, mutual_friends
		where devices.num = mutual_friends.mutual_friend
		and mutual_friends.device = ?};
	$self->{mutual_friend_select} = $dbh->prepare($sql);

	$sql = qq{select devices.os, devices.push_token from devices, mutual_friends
		where devices.num = mutual_friends.mutual_friend
		and mutual_friends.device = ? and devices.push_token is not null};
	$self->{mutual_friend_notify_select} = $dbh->prepare($sql);

	$sql = 'delete from mutual_friends where device = ? and mutual_friend = ?';
	$self->{mutual_friends_delete} = $dbh->prepare($sql);

	# lists/list_members compound queries
	$sql = qq{select lists.num, lists.name, lists.date from lists, list_members where
		lists.num = list_members.list and list_members.device = ?};
	$self->{get_lists} = $dbh->prepare($sql);

	$sql = qq{select devices.phone_num from devices, list_members
		where devices.num = list_members.device and list_members.list = ?};
	$self->{list_members_phnums} = $dbh->prepare($sql);

	$sql = qq{select devices.os, devices.push_token from devices, list_members
		where devices.num = list_members.device and list_members.list = ?
		and list_members.device != ?};
	$self->{select_list_members} = $dbh->prepare($sql);

	# list_members table queries
	$sql = 'select device from list_members where list = ?';
	$self->{get_list_members} = $dbh->prepare($sql);

	$sql = 'insert into list_members (list, device, joined) values (?, ?, ?)';
	$self->{new_list_member} = $dbh->prepare($sql);

	$sql = 'delete from list_members where list = ? and device = ?';
	$self->{remove_list_member} = $dbh->prepare($sql);

	$sql = 'select device from list_members where list = ? and device = ?';
	$self->{check_list_member} = $dbh->prepare($sql);

	$sql = qq{select list from list_members where device = ? except
		select list from list_members where device = ?};
	$self->{get_other_lists} = $dbh->prepare($sql);

	# list_data table queries
	$sql = 'delete from list_data where list = ?';
	$self->{delete_list_data} = $dbh->prepare($sql);

	$sql = 'select * from list_data where list = ?';
	$self->{get_list_items} = $dbh->prepare($sql);

	$sql = 'insert into list_data (list, name, quantity, status, owner, last_updated) values (?, ?, ?, ?, ?, ?)';
	$self->{new_list_item} = $dbh->prepare($sql);
}

1;
