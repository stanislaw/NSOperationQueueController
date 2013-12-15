//
//  NSOperationQueueController_Private.h
//  NSOQCDevelopmentApp
//
//  Created by Stanislaw Pankevich on 15/12/13.
//  Copyright (c) 2013 Stanislaw Pankevich. All rights reserved.
//

#import "NSOperationQueueController.h"

@interface NSOperationQueueController ()

@property (strong) NSMutableArray *pendingOperations;
@property (strong) NSMutableArray *runningOperations;

- (void)_runNextOperationIfExists;

@end
