// NSOperationQueueController
//
// NSOperationQueueController/NSOperationQueueController.h
//
// Copyright (c) 2013 Stanislaw Pankevich
// Released under the MIT license

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, NSOperationQueueControllerOrder) {
    NSOperationQueueControllerOrderFIFO = 0,
    NSOperationQueueControllerOrderLIFO,
    NSOperationQueueControllerOrderAggressiveLIFO
};

@interface NSOperationQueueController : NSObject

- (instancetype)initWithOperationQueue:(NSOperationQueue *)operationQueue;

@property (strong, nonatomic) NSOperationQueue* operationQueue;

@property NSOperationQueueControllerOrder order;

@property (readonly) NSUInteger operationCount;

@property (readonly) NSUInteger maxConcurrentOperationCount;

- (void)addOperationWithBlock:(void(^)(void))operationBlock;
- (void)addOperation:(NSOperation *)operation;

- (void)cancelAllOperations;
- (void)cancelAndRunOutAllPendingOperations;

// Suspend / Resume
@property (readonly) BOOL isSuspended;
- (void)setSuspended:(BOOL)suspend;


// NSObject
- (NSString *)description;
- (NSString *)debugDescription;

@end

