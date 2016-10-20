
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
#import "src.h"
using namespace mp4v2::impl;
@interface RAViewController () <RATreeViewDelegate, RATreeViewDataSource>

@property (strong, nonatomic) NSArray *data;
@property (weak, nonatomic) RATreeView *treeView;

@property (strong, nonatomic) UIBarButtonItem *editButton;

@end

@implementation RAViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
   dispatch_async(dispatch_get_global_queue(0, 0), ^{
       [self loadData];
       dispatch_async(dispatch_get_main_queue(), ^{
           [self.treeView reloadData];
       });
   });
  
  RATreeView *treeView = [[RATreeView alloc] initWithFrame:self.view.bounds];
  treeView.delegate = self;
  treeView.dataSource = self;
  treeView.treeFooterView = [UIView new];
  treeView.separatorStyle = RATreeViewCellSeparatorStyleSingleLine;
    treeView.rowHeight = 60;

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
  NSString *detailText = [NSString stringWithFormat:@"number of children:%lu  %@",(unsigned long)dataObject.children.count, dataObject.property];
  
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
    NSMutableArray* data = [NSMutableArray arrayWithCapacity:4];
   
    MP4File* file = (MP4File*)_fileHandle;
    MP4Atom* superAtom = file->FindAtom(NULL);
    [self loadAtomWith:superAtom superData:nil data:data];
    self.data = data;
    

//    NSFileHandle * handle = [NSFileHandle fileHandleForReadingAtPath:sourcePath];
//    NSData* data = [handle readDataToEndOfFile];
//    
  
//    self.data = [NSArray arrayWithObjects:phone, computer, car, bike, house, flats, motorbike, drinks, food, sweets, watches, walls, nil];
}
-(void)loadAtomWith:(MP4Atom*)superAtom superData:(RADataObject*)superData data:(NSMutableArray*)data{
    for (int j = 0; j< superAtom->GetNumberOfChildAtoms(); j++) {
        MP4Atom* currentAtom = superAtom->GetChildAtom(j);
        NSString* name = [NSString stringWithFormat:@"%s",currentAtom->GetType()];
        NSString* propertystr ;
        for (int i = 0; i<currentAtom->GetCount(); i++) {
            MP4Property* property = currentAtom->GetProperty(i);
            propertystr = [NSString stringWithFormat:@"%@ -- %s:%@",propertystr,property->GetName(),[self getValueWithProperty:property]];

        }
        RADataObject *current = [RADataObject dataObjectWithName:name children:nil];
        current.property = propertystr;
        if (superData) {
            [superData addChild:current];
        }else{
            [data addObject:current];
        }
        [self loadAtomWith:currentAtom superData:current data:data];
    }
}
-(NSString*)getValueWithProperty:(MP4Property*)property{
    NSString* value;
    switch (property->GetType()) {
        case Integer8Property:
        {
            MP4Integer8Property *p = (MP4Integer8Property*)property;
            value = [NSString stringWithFormat:@"Integer8Property__%d",p->GetValue()];
            break;
        }
        case Integer16Property:
        {
            MP4Integer16Property *p = (MP4Integer16Property*)property;
            value = [NSString stringWithFormat:@"Integer16Property__%d",p->GetValue()];
            break;
        }
        case Integer24Property:
        {
            MP4Integer24Property *p = (MP4Integer24Property*)property;
            value = [NSString stringWithFormat:@"Integer24Property__%d",p->GetValue()];
            break;
        }
        case Integer32Property:
        {
            MP4Integer32Property *p = (MP4Integer32Property*)property;
            value = [NSString stringWithFormat:@"Integer32Property__%d",p->GetValue()];
            break;
        }
        case Integer64Property:
        {
            MP4Integer64Property *p = (MP4Integer64Property*)property;
            value = [NSString stringWithFormat:@"Integer64Property__%llu",p->GetValue()];
            break;
        }
        case Float32Property:
        {
            MP4Float32Property *p = (MP4Float32Property*)property;
            value = [NSString stringWithFormat:@"Float32Property__%f",p->GetValue()];
            break;
        }
        case StringProperty:
        {
            MP4StringProperty *p = (MP4StringProperty*)property;
            value = [NSString stringWithFormat:@"StringProperty__%s",p->GetValue()];
            break;
        }
        case BytesProperty:
        {
            uint32_t pValueSize;
            uint8_t* pValue;
            MP4BytesProperty *p = (MP4BytesProperty*)property;
            p->GetValue(&pValue, &pValueSize);
            value=[NSString stringWithFormat:@"BytesProperty__%s",pValue];
            free(pValue);
            break;
        }
        case TableProperty:
             value=[NSString stringWithFormat:@"TableProperty__NULL"];
            break;
        case DescriptorProperty:
             value=[NSString stringWithFormat:@"DescriptorProperty__NULL"];
            break;
        case LanguageCodeProperty:
             value=[NSString stringWithFormat:@"LanguageCodeProperty__NULL"];
            break;
        case BasicTypeProperty:
             value=[NSString stringWithFormat:@"BasicTypeProperty__NULL"];
            break;
        default:
            NSLog(@"error getValue");
            break;
    }
    return value;
}
@end
