//
//  MindOMeterFlipsideViewController.m
//  MindOMeter
//
//  Created by Grant Patterson on 11/21/12.
//  Copyright (c) 2012 Grant Patterson. All rights reserved.
//

#import "MindOMeterFlipsideViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface MindOMeterFlipsideViewController () <UITableViewDataSource, UITableViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *settingsTable;
@property (weak, nonatomic) IBOutlet UIView *contentView;

@end

@implementation MindOMeterFlipsideViewController {
    NSMutableArray* selectedWaves;
}

@synthesize contentView;

- (void)awakeFromNib
{
    self.contentSizeForViewInPopover = CGSizeMake(320.0, 480.0);
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    selectedWaves = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"selectedWaves"] mutableCopy];
    
    self.settingsTable.delegate = self;
    self.settingsTable.dataSource = self;
    
    
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return 1;
        case 1:
            return [self.waveOrder count];
        case 2:
            return 3; // XXX
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row > 0) {
            return nil;
        }
        UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Background Setting"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Background Setting"];
            cell.textLabel.text = @"Run in Background";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        UISwitch *bgSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
        cell.accessoryView = bgSwitch;
        [bgSwitch setOn:[[NSUserDefaults standardUserDefaults] boolForKey:@"runInBackground"] animated:NO];
        [bgSwitch addTarget:self action:@selector(bgSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        return cell;
    } else if (indexPath.section == 1) {
        if (indexPath.row >= [self.waveOrder count]) {
            return nil;
        }
        UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"Wave Choice"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Wave Choice"];
        }
        NSDictionary* properties = self.waveProperties[self.waveOrder[indexPath.row]];
        cell.textLabel.text = properties[@"longLabel"];
        cell.detailTextLabel.text = properties[@"desc"];
        cell.accessoryType = [selectedWaves containsObject:self.waveOrder[indexPath.row]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        
        // We want to use the standard label type, so create an image of the glyphs. Besides, we want to tweak its placement.
        // Scale of 0 means do the right thing for retina.
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(47, 44), NO, 0);
        [[UIColor colorWithHue:[properties[@"hue"] floatValue] saturation:[properties[@"sat"] floatValue] brightness:0.7 alpha:1] set];
        [properties[@"label"] drawAtPoint:CGPointMake(10 + [properties[@"labelXOff"] floatValue], -5.0 + [properties[@"labelYOff"] floatValue]) withFont:[UIFont fontWithName:@"Cochin-Bold" size:44]];
        UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        cell.imageView.image = image;
        
        return cell;
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return @"Displayed Waves";
    } else if (section == 2) {
        return @"Saved Sessions";
    }
    return nil;    
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return [[@"With this on, your headset will send data even while you use other apps or your " stringByAppendingString:[UIDevice currentDevice].localizedModel] stringByAppendingString: @" is asleep."];
    }
    return nil;
}

- (void) bgSwitchChanged:(id)sender {
    UISwitch* bgSwitch = sender;
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(bgSwitch.on) forKey:@"runInBackground"];
    [defaults synchronize];
}

- (void)tableView:(UITableView *)theTableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
    [theTableView deselectRowAtIndexPath:[theTableView indexPathForSelectedRow] animated:NO];
    if (newIndexPath.section != 1) {
        return;
    }
    
    UITableViewCell* cell = [theTableView cellForRowAtIndexPath:newIndexPath];
    if (cell.accessoryType == UITableViewCellAccessoryNone) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        
        if ([selectedWaves containsObject:self.waveOrder[newIndexPath.row]]) {
            NSLog(@"XXX: why are we unchecking for row %d when %@ is already in selectedWaves???", newIndexPath.row, self.waveOrder[newIndexPath.row]);
        } else {
            // XXX: All ways I can think of doing this suck.
            NSMutableArray* newSelected = [[NSMutableArray alloc] init];
            for (int i = 0; i < [self.waveOrder count]; i++) {
                if (i == newIndexPath.row || [selectedWaves containsObject:self.waveOrder[i]]) {
                    [newSelected addObject:self.waveOrder[i]];
                }
            }
            selectedWaves = newSelected;
            //[selectedWaves addObject:self.waveOrder[newIndexPath.row]];
        }
    } else if (cell.accessoryType == UITableViewCellAccessoryCheckmark) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        if (![selectedWaves containsObject:self.waveOrder[newIndexPath.row]]) {
            NSLog(@"XXX: why are we checking for row %d when %@ isn't in selectedWaves???", newIndexPath.row, self.waveOrder[newIndexPath.row]);
        } else {
            [selectedWaves removeObject:self.waveOrder[newIndexPath.row]];
        }
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([selectedWaves count] <= 1 &&
        [tableView cellForRowAtIndexPath:indexPath].accessoryType == UITableViewCellAccessoryCheckmark) {
        // This would remove the only remaining row, so disallow selection.
        return nil;
    }
    return indexPath;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:selectedWaves forKey:@"selectedWaves"];
    [defaults synchronize];
    
    [self.delegate flipsideViewControllerDidFinish:self];
}

- (void)viewDidUnload {
    [self setContentView:nil];
    [self setSettingsTable:nil];
    [super viewDidUnload];
}
@end
