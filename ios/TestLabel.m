#import "TestLabel.h"
 
@implementation TestLabel
-(instancetype)initWithBackgroundColor:(UIColor *)backgroundColor
{
    if(self == [self init])
    {
        self.backgroundColor = backgroundColor;
        self.textColor = UIColor.whiteColor;
        self.text = @"rofl";
        self.frame = CGRectMake(20,20,300,300);
    }
    return self;
}
@end
