
//The MIT License (MIT)
//
//Copyright (c) 2014 Rafał Augustyniak
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of
//this software and associated documentation files (the "Software"), to deal in
//the Software without restriction, including without limitation the rights to
//use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//the Software, and to permit persons to whom the Software is furnished to do so,
//subject to the following conditions:
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "RAViewController.h"
#import "RATreeView.h"
#import "RADataObject.h"

#import "RATableViewCell.h"
#import "mp4v2.h"


@interface RAViewController () <RATreeViewDelegate, RATreeViewDataSource>

@property (strong, nonatomic) NSArray *data;
@property (weak, nonatomic) RATreeView *treeView;

@property (strong, nonatomic) UIBarButtonItem *editButton;

@end

@implementation RAViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self loadData];
  
  RATreeView *treeView = [[RATreeView alloc] initWithFrame:self.view.bounds];
  treeView.delegate = self;
  treeView.dataSource = self;
  treeView.treeFooterView = [UIView new];
  treeView.separatorStyle = RATreeViewCellSeparatorStyleSingleLine;
    treeView.rowHeight = 44;

  UIRefreshControl *refreshControl = [UIRefreshControl new];
  [refreshControl addTarget:self action:@selector(refreshControlChanged:) forControlEvents:UIControlEventValueChanged];
  [treeView.scrollView addSubview:refreshControl];
  
  [treeView reloadData];
  [treeView setBackgroundColor:[UIColor colorWithWhite:0.97 alpha:1.0]];
  
  
  self.treeView = treeView;
  self.treeView.frame = self.view.bounds;
  self.treeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.view insertSubview:treeView atIndex:0];
  
  [self.navigationController setNavigationBarHidden:NO];
  self.navigationItem.title = NSLocalizedString(@"Things", nil);
  [self updateNavigationItemButton];
  
  [self.treeView registerNib:[UINib nibWithNibName:NSStringFromClass([RATableViewCell class]) bundle:nil] forCellReuseIdentifier:NSStringFromClass([RATableViewCell class])];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  
  int systemVersion = [[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."][0] intValue];
  if (systemVersion >= 7 && systemVersion < 8) {
    CGRect statusBarViewRect = [[UIApplication sharedApplication] statusBarFrame];
    float heightPadding = statusBarViewRect.size.height+self.navigationController.navigationBar.frame.size.height;
    self.treeView.scrollView.contentInset = UIEdgeInsetsMake(heightPadding, 0.0, 0.0, 0.0);
    self.treeView.scrollView.contentOffset = CGPointMake(0.0, -heightPadding);
  }
  
  self.treeView.frame = self.view.bounds;
}


#pragma mark - Actions 

- (void)refreshControlChanged:(UIRefreshControl *)refreshControl
{
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [refreshControl endRefreshing];
  });
}

- (void)editButtonTapped:(id)sender
{
  [self.treeView setEditing:!self.treeView.isEditing animated:YES];
  [self updateNavigationItemButton];
}

- (void)updateNavigationItemButton
{
  UIBarButtonSystemItem systemItem = self.treeView.isEditing ? UIBarButtonSystemItemDone : UIBarButtonSystemItemEdit;
  self.editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:systemItem target:self action:@selector(editButtonTapped:)];
  self.navigationItem.rightBarButtonItem = self.editButton;
}


#pragma mark TreeView Delegate methods



- (BOOL)treeView:(RATreeView *)treeView canEditRowForItem:(id)item
{
  return YES;
}

- (void)treeView:(RATreeView *)treeView willExpandRowForItem:(id)item
{
  RATableViewCell *cell = (RATableViewCell *)[treeView cellForItem:item];
  [cell setAdditionButtonHidden:NO animated:YES];
}

- (void)treeView:(RATreeView *)treeView willCollapseRowForItem:(id)item
{
  RATableViewCell *cell = (RATableViewCell *)[treeView cellForItem:item];
  [cell setAdditionButtonHidden:YES animated:YES];
}

- (void)treeView:(RATreeView *)treeView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowForItem:(id)item
{
  if (editingStyle != UITableViewCellEditingStyleDelete) {
    return;
  }
  
  RADataObject *parent = [self.treeView parentForItem:item];
  NSInteger index = 0;
  
  if (parent == nil) {
    index = [self.data indexOfObject:item];
    NSMutableArray *children = [self.data mutableCopy];
    [children removeObject:item];
    self.data = [children copy];
    
  } else {
    index = [parent.children indexOfObject:item];
    [parent removeChild:item];
  }
  
  [self.treeView deleteItemsAtIndexes:[NSIndexSet indexSetWithIndex:index] inParent:parent withAnimation:RATreeViewRowAnimationRight];
  if (parent) {
    [self.treeView reloadRowsForItems:@[parent] withRowAnimation:RATreeViewRowAnimationNone];
  }
}

#pragma mark TreeView Data Source

- (UITableViewCell *)treeView:(RATreeView *)treeView cellForItem:(id)item
{
  RADataObject *dataObject = item;
  
  NSInteger level = [self.treeView levelForCellForItem:item];
  NSInteger numberOfChildren = [dataObject.children count];
  NSString *detailText = [NSString localizedStringWithFormat:@"Number of children %@", [@(numberOfChildren) stringValue]];
  BOOL expanded = [self.treeView isCellForItemExpanded:item];
  
  RATableViewCell *cell = [self.treeView dequeueReusableCellWithIdentifier:NSStringFromClass([RATableViewCell class])];
  [cell setupWithTitle:dataObject.name detailText:detailText level:level additionButtonHidden:!expanded];
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  
  __weak typeof(self) weakSelf = self;
  cell.additionButtonTapAction = ^(id sender){
    if (![weakSelf.treeView isCellForItemExpanded:dataObject] || weakSelf.treeView.isEditing) {
      return;
    }
    RADataObject *newDataObject = [[RADataObject alloc] initWithName:@"Added value" children:@[]];
    [dataObject addChild:newDataObject];
    [weakSelf.treeView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:0] inParent:dataObject withAnimation:RATreeViewRowAnimationLeft];
    [weakSelf.treeView reloadRowsForItems:@[dataObject] withRowAnimation:RATreeViewRowAnimationNone];
  };
  
  return cell;
}

- (NSInteger)treeView:(RATreeView *)treeView numberOfChildrenOfItem:(id)item
{
  if (item == nil) {
    return [self.data count];
  }
  
  RADataObject *data = item;
  return [data.children count];
}

- (id)treeView:(RATreeView *)treeView child:(NSInteger)index ofItem:(id)item
{
  RADataObject *data = item;
  if (item == nil) {
    return [self.data objectAtIndex:index];
  }
  
  return data.children[index];
}

#pragma mark - Helpers 

- (void)loadData
{
  RADataObject *phone1 = [RADataObject dataObjectWithName:@"Phone 1" children:nil];
  RADataObject *phone2 = [RADataObject dataObjectWithName:@"Phone 2" children:nil];
  RADataObject *phone3 = [RADataObject dataObjectWithName:@"Phone 3" children:nil];
  RADataObject *phone4 = [RADataObject dataObjectWithName:@"Phone 4" children:nil];
    NSString* sourcePath = [[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
   MP4FileHandle* fileHandle =  MP4Read(sourcePath.UTF8String);
    
    
//    NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:sourcePath];
//    NSData* data = [handle readDataToEndOfFile];
//    
  
//    self.data = [NSArray arrayWithObjects:phone, computer, car, bike, house, flats, motorbike, drinks, food, sweets, watches, walls, nil];
}

@end
