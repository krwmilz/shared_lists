#import "AppDelegate.h"
#import "Network.h"

#import <CoreData/CoreData.h>

@interface AppDelegate () {
	Network *network_connection;
}

@end

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// we need to issue connect/reconnects from here
	network_connection = [Network shared_network_connection];

	// Register the supported interaction types.
	[[UIApplication sharedApplication] registerForRemoteNotificationTypes:UIRemoteNotificationTypeBadge];

	// customization after application launch
	return YES;
}

// Handle remote notification registration.
- (void)application:(UIApplication *)app
	didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)devToken
{
	const unsigned char *token_data = [devToken bytes];
	NSUInteger token_length = [devToken length];

	NSMutableString *hex_token = [NSMutableString stringWithCapacity:(token_length * 2)];
	for (int i = 0; i < token_length; i++) {
		[hex_token appendFormat:@"%02lX", (unsigned long)token_data[i]];
	}

	NSLog(@"apn: device token is 0x%@", hex_token);
	if ([network_connection get_device_id] != nil) {
		[network_connection send_message:device_update contents:hex_token];
	}
}

// Called when push notification received
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
	NSLog(@"notify: got remote notification");

	NSString *msg_type = userInfo[@"msg_type"];
	if (msg_type == nil) {
		NSLog(@"didReceiveRemoteNotification: did not have 'msg_type' key");
		return;
	}

	// Create unique notification name based on the incoming message type
	NSString *notification_name = [NSString stringWithFormat:@"PushNotification_%@", userInfo[@"msg_type"]];

	if (![userInfo[@"payload"] isKindOfClass:[NSDictionary class]]) {
		NSLog(@"didReceiveRemoteNotification: payload wasn't a dictionary");
		return;
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:notification_name object:nil userInfo:userInfo[@"payload"]];
}

- (void) applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive
	// state. This can occur for certain types of temporary interruptions
	// (such as an incoming phone call or SMS message) or when the user
	// quits the application and it begins the transition to the background
	// state.
	//
	// Use this method to pause ongoing tasks, disable timers, and throttle
	// down OpenGL ES frame rates. Games should use this method to pause the
	// game.
}

- (void) applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data,
	// invalidate timers, and store enough application state information to
	// restore your application to its current state in case it is
	// terminated later.
	// If your application supports background execution, this method is
	// called instead of applicationWillTerminate: when the user quits.

	NSLog(@"info: app: entering background, disconnecting network");
	[network_connection disconnect];
}

- (void) applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive
	// state; here you can undo many of the changes made on entering the
	// background.

	NSLog(@"info: app: entering foreground, reconnecting...");
	[network_connection connect];
	//[network_connection send_message:lists_get contents:[[NSMutableDictionary alloc] init]];
	//[network_connection send_message:lists_get_other contents:[[NSMutableDictionary alloc] init]];
}

- (void) applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the
	// application was inactive. If the application was previously in the
	// background, optionally refresh the user interface.
}

- (void) applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if
	// appropriate. See also applicationDidEnterBackground:.

	NSLog(@"info: app: teminating, disconnecting network");
	[network_connection disconnect];
}

- (void)application:(UIApplication *)app
	didFailToRegisterForRemoteNotificationsWithError:(NSError *)err
{
	NSLog(@"Error in registration. Error: %@", err);
}

- (void)saveContext
{
	NSError *error = nil;
	NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
	if (managedObjectContext != nil) {
		if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
			// Replace this implementation with code to handle the error appropriately.
			// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
			NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
			abort();
		}
	}
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
	if (_managedObjectContext != nil) {
		return _managedObjectContext;
	}

	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (coordinator != nil) {
		_managedObjectContext = [[NSManagedObjectContext alloc] init];
		[_managedObjectContext setPersistentStoreCoordinator:coordinator];
	}
	return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
	if (_managedObjectModel != nil) {
		return _managedObjectModel;
	}
	NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"shlist" withExtension:@"momd"];
	_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
	if (_persistentStoreCoordinator != nil) {
		return _persistentStoreCoordinator;
	}

	NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"shlist.sqlite"];

	NSError *error = nil;
	_persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
	if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
		/*
		 Replace this implementation with code to handle the error appropriately.

		 abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

		 Typical reasons for an error here include:
		 * The persistent store is not accessible;
		 * The schema for the persistent store is incompatible with current managed object model.
		 Check the error message to determine what the actual problem was.

		 If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.

		 If you encounter schema incompatibility errors during development, you can reduce their frequency by:
		 * Simply deleting the existing store:
		 [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]

		 * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
		 @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}

		 Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.

		 */
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
	}

	return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
	return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end