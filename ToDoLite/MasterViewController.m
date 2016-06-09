//
//  MasterViewController.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/11/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import "MasterViewController.h"
#import "DetailViewController.h"
#import "AppDelegate.h"
#import "Profile.h"
#import "List.h"

static void *listsQueryContext = &listsQueryContext;

@interface MasterViewController ()

@property CBLDatabase *database;
@property CBLLiveQuery *liveQuery;
@property NSArray *listsResult;

@end

@implementation MasterViewController

- (void)awakeFromNib {
    [super awakeFromNib];
    self.title = @"ToDo Lists";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setup];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (!self.database) {
        [self setup];
    }
    
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app addObserver:self forKeyPath:@"database"
             options:(NSKeyValueObservingOptionNew |  NSKeyValueObservingOptionOld) context:nil];

    self.loginButton.title = [app isUserLoggedIn] ? @"Logout" : @"Login";

    NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
    if (selected) {
        [self.tableView deselectRowAtIndexPath:selected animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app removeObserver:self forKeyPath:@"database" context:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [self.liveQuery removeObserver:self forKeyPath:@"rows" context:listsQueryContext];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        CBLQueryRow *row = [self.listsResult objectAtIndex:indexPath.row];
        List *list = [List modelForDocument:row.document];
        
        DetailViewController *controller = [segue destinationViewController];
        controller.list = list;
    }
}

#pragma mark - Buttons

- (IBAction)addButtonAction:(id)sender {
    UIAlertView* alert= [[UIAlertView alloc] initWithTitle:@"New ToDo List"
                                                   message:@"Title for new list:"
                                                  delegate:self
                                         cancelButtonTitle:@"Cancel"
                                         otherButtonTitles:@"Create", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

- (IBAction)loginButtonAction:(id)sender {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    [app logout];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alert didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex > 0) {
        NSString* title = [alert textFieldAtIndex:0].text;
        if (title.length > 0) {
            [self createListWithTitle:title];
        }
    }
}

#pragma mark - Table View Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.listsResult.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"List"
                                                            forIndexPath:indexPath];

    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    CBLQueryRow* row = [self.listsResult objectAtIndex:indexPath.row];
    cell.textLabel.text = [row.document propertyForKey:@"title"];
    
    return cell;
}

#pragma mark - Table View Delegate

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)style
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete) {
        CBLQueryRow* row = [self.listsResult objectAtIndex:indexPath.row];
        List *list = [List modelForDocument:row.document];
        [list deleteList:nil];
    }
}

#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    if (object == app && [keyPath isEqual:@"database"]) {
        [self setup];
    }
    if (context == listsQueryContext) {
        self.listsResult = self.liveQuery.rows.allObjects;
        [self.tableView reloadData];
    }
}

#pragma mark - Database

// In this View Controller, we show an example of a Live Query
// and KVO to update the Table View accordingly when data changed.
// See DetailViewController and ShareViewController for
// examples of a Live Query used with the CBLUITableSource api.
- (void)setup {
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    self.database = app.database;
    
    [self.liveQuery removeObserver:self forKeyPath:@"rows" context:listsQueryContext];
    if (self.database != nil) {
        self.liveQuery = [List queryListsInDatabase:self.database].asLiveQuery;
        [self.liveQuery addObserver:self forKeyPath:@"rows" options:0 context:listsQueryContext];
    } else {
        self.liveQuery = nil;
    }
    
    [self.tableView reloadData];
}

- (List *)createListWithTitle:(NSString*)title {
    List *list = [List modelForNewDocumentInDatabase:self.database];
    list.title = title;
    
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    NSString *currentUserId = app.currentUserId;
    if (currentUserId) {
        Profile *owner = [Profile profileInDatabase:self.database forExistingUserId:currentUserId];
        list.owner = owner;
    }
    
    NSError *error;
    if (![list save:&error]) {
        [app showMessage:@"Cannot create a new list" withTitle:@"Error"];
        return nil;
    }
    
    return list;
}

@end
