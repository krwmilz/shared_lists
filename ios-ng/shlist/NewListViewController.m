#import "NewListViewController.h"

@interface NewListViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem *saveButton;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIDatePicker *datePicker;

@end

@implementation NewListViewController


- (void) viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void) didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Navigation

// preparation before navigation
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	// Get the new view controller using [segue destinationViewController].
	// Pass the selected object to the new view controller.

	if (sender != self.saveButton) return;

	if (self.textField.text.length > 0) {
		self.shared_list = [[SharedList alloc] init];
		self.shared_list.name = self.textField.text;
		// self.shared_list.list_date = self.datePicker.date;
		// self.shared_list.members = @"You";

		NSLog(@"NewListViewController::prepareForSegue(): %@", self.textField.text);
	}
}

@end