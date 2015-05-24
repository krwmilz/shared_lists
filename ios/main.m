#import <UIKit/UIKit.h>
#import "TestLabel.h"
 
@interface TestAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
 
int main(int argc, char *argv[])
{
    @autoreleasepool
    {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(TestAppDelegate.class));
    }
}
 
@implementation TestAppDelegate
@synthesize window=_window;
 
-(BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [UIWindow.alloc initWithFrame:UIScreen.mainScreen.bounds];
    self.window.backgroundColor = UIColor.redColor;
 
    UILabel *label = [[TestLabel alloc] initWithBackgroundColor:self.window.backgroundColor];
    [self.window addSubview:label];
    [label release];
 
    [self.window makeKeyAndVisible];
 
    return true;
}
 
@end
