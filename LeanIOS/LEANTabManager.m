//
//  LEANTabManager.m
//  GoNativeIOS
//
//  Created by Weiyin He on 8/14/14.
//  Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANTabManager.h"
#import "LEANUtilities.h"
#import "GonativeIO-Swift.h"

@interface LEANTabManager() <UITabBarDelegate>
@property UITabBar *tabBar;
@property NSArray *menu;
@property (weak, nonatomic) LEANWebViewController* wvc;
@property NSString *currentMenuID;
@property BOOL showTabBar;
@property NSMutableDictionary<NSObject*, NSArray<NSPredicate*>*> *tabRegexCache;
@end

@implementation LEANTabManager

- (instancetype)initWithTabBar:(UITabBar*)tabBar webviewController:(LEANWebViewController*)wvc;
{
    self = [super init];
    if (self) {
        self.tabBar = tabBar;
        self.tabBar.delegate = self;
        self.tabBar.unselectedItemTintColor = [UIColor colorNamed:@"inactiveTabBarItemColor"];
        self.wvc = wvc;
        self.showTabBar = NO;
        self.javascriptTabs = NO;
        self.tabRegexCache = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)didLoadUrl:(NSURL *)url
{
    if (self.javascriptTabs) {
        [self autoSelectTabForUrl:url];
        return;
    }
    
    NSArray *tabMenuRegexes = [GoNativeAppConfig sharedAppConfig].tabMenuRegexes;
    if (!tabMenuRegexes || !url) return;
    
    NSString *urlString = [url absoluteString];
    
    BOOL showTabBar = NO;
    for (NSUInteger i = 0; i < [tabMenuRegexes count]; i++) {
        NSPredicate *predicate = tabMenuRegexes[i];
        if ([predicate evaluateWithObject:urlString]) {
            [self loadTabBarMenu:[GoNativeAppConfig sharedAppConfig].tabMenuIDs[i]];
            showTabBar = YES;
            break;
        }
    }
    
    if (showTabBar) {
        if (!self.showTabBar) {
            // select first item
            if ([self.tabBar.items count] > 0 && !self.tabBar.selectedItem) {
                self.tabBar.selectedItem = self.tabBar.items[0];
            }
        }
        [self.wvc showTabBarAnimated:YES];
    } else {
        [self.wvc hideTabBarAnimated:YES];
    }
    
    self.showTabBar = showTabBar;
    
    [self autoSelectTabForUrl:url];
}

- (void)loadTabBarMenu:(NSString*)menuID
{
    if ([menuID isEqualToString:self.currentMenuID]) {
        return;
    }
    
    NSArray *menu = [GoNativeAppConfig sharedAppConfig].tabMenus[menuID];
    
    if (menu) {
        self.currentMenuID = menuID;
        [self setTabBarItems:menu];
    }
}

- (CGFloat)titleOffsetY {
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return 0;
    }
    if (self.wvc.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassCompact && self.menu.count < 6) {
        return -7;
    }
    return 0;
}

- (CGFloat)sizeForIcon:(NSString *)iconName {
    CGFloat size = 20;
    if ([iconName hasPrefix:@"custom "]) {
        size = size * 1.1;
    } else if ([iconName hasPrefix:@"md "]) {
        size = size * 1.25;
    }
    return size;
}

- (UITabBarItem *)createOrUpdateTabBarItem:(UITabBarItem *)tabBarItem withTitle:(NSString *)title activeIcon:(NSString *)activeIcon inactiveIcon:(NSString *)inactiveIcon tag:(NSInteger)tag {
    UITabBarItem *item = tabBarItem;
    if (!item) {
        if (!inactiveIcon) {
            inactiveIcon = activeIcon;
        }
        
        UIImage *activeImage = [LEANIcons imageForIconIdentifier:activeIcon size:[self sizeForIcon:activeIcon] color:[UIColor blackColor]];
        UIImage *inactiveImage = [LEANIcons imageForIconIdentifier:inactiveIcon size:[self sizeForIcon:inactiveIcon] color:[UIColor blackColor]];
        item = [[UITabBarItem alloc] initWithTitle:title image:inactiveImage selectedImage:activeImage];
        item.tag = tag;
    }
    
    [item setTitlePositionAdjustment:UIOffsetMake(0, [self titleOffsetY])];
    return item;
}

- (void)setTabBarItems:(NSArray*) menu {
    NSMutableArray *items = [[NSMutableArray alloc] initWithCapacity:[menu count]];
    
    UITabBarItem *selectedItem;
    
    for (NSUInteger i = 0; i < [menu count]; i++) {
        NSString *label = menu[i][@"label"];
        NSString *activeIcon = menu[i][@"icon"];
        NSString *inactiveIcon = menu[i][@"inactiveIcon"];
        
        if (![label isKindOfClass:[NSString class]]) {
            label = @"";
        }
        
        if (![activeIcon isKindOfClass:[NSString class]]) {
            activeIcon = @"md mi-question-mark";
        }
        
        UITabBarItem *item = [self createOrUpdateTabBarItem:nil withTitle:label activeIcon:activeIcon inactiveIcon:inactiveIcon tag:i];
        [items addObject:item];
        
        if ([menu[i][@"selected"] boolValue]) {
            selectedItem = item;
        }
    }
    
    self.menu = menu;
    [self.tabBar setItems:items animated:NO];
    if (selectedItem) {
        self.tabBar.selectedItem = selectedItem;
    }
}

-(void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    if (previousTraitCollection.verticalSizeClass == self.wvc.traitCollection.verticalSizeClass || !self.menu) {
        return;
    }
    
    // Resize title position offset on wide screens
    for (NSUInteger i = 0; i < [self.menu count]; i++) {
        UITabBarItem *item = self.tabBar.items[i];
        NSString *label = self.menu[i][@"label"];
        NSString *activeIcon = self.menu[i][@"icon"];
        NSString *inactiveIcon = self.menu[i][@"inactiveIcon"];
        [self createOrUpdateTabBarItem:item withTitle:label activeIcon:activeIcon inactiveIcon:inactiveIcon tag:i];
    }
}

- (NSArray<NSPredicate*>*) getRegexForTab:(NSDictionary*) tabConfig
{
    if (![tabConfig isKindOfClass:[NSDictionary class]]) return nil;
    
    id regex = tabConfig[@"regex"];
    if (!regex) return nil;
    
    return [LEANUtilities createRegexArrayFromStrings:regex];
}

- (NSArray<NSPredicate*>*) getCachedRegexForTab:(NSInteger) position
{
    if (!self.menu || position < 0 || position >= [self.menu count]) return nil;
    
    NSDictionary *tabConfig = self.menu[position];
    if (![tabConfig isKindOfClass:[NSDictionary class]]) return nil;
    
    NSArray<NSPredicate*>* cached = self.tabRegexCache[tabConfig];
    if ([cached isKindOfClass:[NSNumber class]]) return nil;
    else {
        NSArray<NSPredicate*>* regex = [self getRegexForTab:tabConfig];
        NSString *url = tabConfig[@"url"];
        
        if (regex) {
            self.tabRegexCache[tabConfig] = regex;
            return regex;
        }
        else if ([url isKindOfClass:[NSString class]]) {
            regex = @[[NSPredicate predicateWithFormat:@"SELF == %@", url]];
            self.tabRegexCache[tabConfig] = regex;
            return regex;
        }
        else {
            self.tabRegexCache[tabConfig] = (NSArray<NSPredicate*>*)[NSNull null];
            return nil;
        }
    }
}

- (void)autoSelectTabForUrl:(NSURL*)url
{
    if (!self.menu) return;
    
    NSString *urlString = [url absoluteString];
    
    for (NSInteger i = 0; i < [self.menu count]; i++) {
        NSArray<NSPredicate*> *regexList = [self getCachedRegexForTab:i];
        if (!regexList) {
            continue;
        }
        
        for (NSPredicate *regex in regexList) {
            BOOL matches = NO;
            @try {
                matches = [regex evaluateWithObject:urlString];
            }
            @catch (NSException* exception) {
                NSLog(@"Error in tab selection regex: %@", exception);
            }

            if (matches) {
                self.tabBar.selectedItem = self.tabBar.items[i];
                return;
            }
        }
    }
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item
{
    NSInteger idx = item.tag;
    if (idx < [self.menu count]) {
        NSString *url = self.menu[idx][@"url"];
        [self.wvc handleJsNavigationUrl:url];
    }
}

- (void)selectTabWithUrl:(NSString*)url {
    for (NSUInteger i = 0; i < [self.menu count]; i++) {
        NSString *entryUrl = self.menu[i][@"url"];
        
        if ([url isEqualToString:entryUrl]) {
            UITabBarItem *item = self.tabBar.items[i];
            if (item) {
                self.tabBar.selectedItem = item;
                return;
            }
        }
    }
}

- (void)selectTabNumber:(NSUInteger)number
{
    if (number >= self.tabBar.items.count) {
        NSLog(@"Invalid tab number %lu", (unsigned long)number);
        return;
    }
    
    self.tabBar.selectedItem = self.tabBar.items[number];
}

- (void)deselectTabs
{
    self.tabBar.selectedItem = nil;
}

- (void)setTabsWithJson:(NSDictionary*)json;
{
    NSNumber *showTabBar = json[@"enabled"];
    if (![showTabBar isKindOfClass:[NSNumber class]]) {
       return;
    }
    self.showTabBar = [showTabBar boolValue];

    if (self.showTabBar) {
       NSArray *menu = json[@"items"];
       if ([menu isKindOfClass:[NSArray class]]) {
           [self setTabBarItems:menu];
           [self.wvc showTabBarAnimated:YES];
           self.javascriptTabs = YES;
           self.currentMenuID = nil;
       } else {
           NSString *menuID = json[@"tabMenu"];
           if ([menuID isKindOfClass:[NSString class]] && menuID.length > 0) {
               [self loadTabBarMenu:menuID];
               self.javascriptTabs = NO;
           }
           [self.wvc showTabBarAnimated:YES];
       }
    } else {
       [self.wvc hideTabBarAnimated:YES];
       self.javascriptTabs = YES;
       self.currentMenuID = nil;
    }
}

- (void)handleUrl:(NSURL *)url query:(NSDictionary *)query {
    if ([url.path hasPrefix:@"/select/"]) {
        NSArray *components = url.pathComponents;
        if (components.count == 3) {
            NSInteger tabNumber = [components[2] integerValue];
            if (tabNumber >= 0) {
                [self selectTabNumber:tabNumber];
            }
        }
    }
    else if ([@"/deselect" isEqualToString:url.path]) {
        [self deselectTabs];
    }
    else if ([@"/setTabs" isEqualToString:url.path]) {
        id tabs = query[@"tabs"];
        
        if([tabs isKindOfClass:[NSString class]]) {
            tabs = [NSJSONSerialization JSONObjectWithData:[tabs dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        }
        
        if([tabs isKindOfClass:[NSDictionary class]]) {
            [self setTabsWithJson:tabs];
            self.javascriptTabs = YES;
        }
    }
}

@end
