/* generated Tue 12 Jan 2016 20:40:15 MST */
#import "Network.h"

/*
@interface MsgTypes : NSObject  {
	NSPointerArray *array;
}
*/

int protocol_version = 0;
enum msg_types {
	device_add = 0,
	friend_add = 1,
	friend_delete = 2,
	list_add = 3,
	list_join = 4,
	list_leave = 5,
	lists_get = 6,
	lists_get_other = 7,
	list_items_get = 8,
	list_item_add = 9,
};

/*
@end
@implementation MsgTypes
+ (void)initialize {
	//array = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsOpaqueMemory];
}
*/

//NSPointerArray *array = [NSPointerArray pointerArrayWithOptions:NSPointerFunctionsOpaqueMemory];
//NSArray *msg_func = @[[NSValue valueWithPointer:handlerA]];
