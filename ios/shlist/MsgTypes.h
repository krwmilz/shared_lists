/* generated Sat Feb 20 15:18:31 MST 2016 */

int protocol_version = 0;
enum msg_types {
	device_add = 0,
	device_update = 1,
	friend_add = 2,
	friend_delete = 3,
	list_add = 4,
	list_update = 5,
	list_join = 6,
	list_leave = 7,
	lists_get = 8,
	lists_get_other = 9,
	list_items_get = 10,
	list_item_add = 11,
};
static const char *msg_strings[] = {
	"device_add",
	"device_update",
	"friend_add",
	"friend_delete",
	"list_add",
	"list_update",
	"list_join",
	"list_leave",
	"lists_get",
	"lists_get_other",
	"list_items_get",
	"list_item_add",
};
