#import "AppDelegate.h"
#import "Network.h"

@interface AppDelegate () {
	Network *network_connection;
}

@end

@implementation AppDelegate


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

	NSMutableDictionary *request = [[NSMutableDictionary alloc] init];
	[request setObject:hex_token forKey:@"pushtoken_hex"];
	[network_connection send_message:device_update contents:request];
}

// Called when push notification received
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
{
	NSLog(@"notify: got remote notification");
	for (id key in userInfo) {
		NSLog(@"notify: '%@' => '%@'", key, userInfo[key]);
	}
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MessageReceivedNotification" object:nil userInfo:userInfo];
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
	[network_connection send_message:lists_get contents:[[NSMutableDictionary alloc] init]];
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

@end