// NSOperationQueueController
//
// NSOperationQueueController/NSOperationQueueController.m
//
// Copyright (c) 2013 Stanislaw Pankevich
// Released under the MIT license

#import "NSOperationQueueController.h"

#import "NSOperationQueueController_Private.h"

@implementation NSOperationQueueController

- (instancetype)initWithOperationQueue:(NSOperationQueue *)operationQueue {
    self = [self init];

    if (self == nil) return nil;

    self.operationQueue = operationQueue;

    return self;
}

- (id)init {
    self = [super init];

    self.pendingOperations = [NSMutableArray array];
    self.runningOperations = [NSMutableArray array];

    self.order = NSOperationQueueControllerOrderFIFO;

    return self;
}

- (void)dealloc {
    self.pendingOperations = nil;
    self.runningOperations = nil;
}

#pragma mark
#pragma mark Properties

- (NSUInteger)operationCount {
    NSUInteger operationCount;

    @synchronized(self) {
        operationCount = self.pendingOperations.count + self.runningOperations.count;
    }

    return operationCount;
}

#pragma mark
#pragma mark NSOperation

- (NSUInteger)maxConcurrentOperationCount {
    if (self.operationQueue) {
        return self.operationQueue.maxConcurrentOperationCount;
    } else {
        return NSNotFound;
    }
}

- (void)addOperation:(NSOperation *)operation {
    if (self.operationQueue == nil) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"NSOperationQueueController: operation queue should be defined" userInfo:nil];
    }

    @synchronized(self) {
        switch (self.order) {
            case NSOperationQueueControllerOrderFIFO:
                [self.pendingOperations addObject:operation];

                break;

            case NSOperationQueueControllerOrderLIFO:
                [self.pendingOperations insertObject:operation atIndex:0];

                break;

            case NSOperationQueueControllerOrderAggressiveLIFO:
                if (self.maxConcurrentOperationCount > 0 && self.maxConcurrentOperationCount != NSOperationQueueDefaultMaxConcurrentOperationCount && self.pendingOperations.count == self.maxConcurrentOperationCount) {
                    NSOperation *operation = self.pendingOperations.lastObject;
                    [self.pendingOperations removeObject:operation];

                    [operation cancel];
                }

                [self.pendingOperations insertObject:operation atIndex:0];

                break;
                
            default:
                break;
        }
    }
    
    [self _runNextOperationIfExists];
}

- (void)addOperationWithBlock:(void (^)(void))operationBlock {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:operationBlock];

    [self addOperation:operation];
}

- (BOOL)isSuspended {
    if (self.operationQueue) {
        return self.operationQueue.isSuspended;
    } else {
        return NO;
    }
}

- (void)setSuspended:(BOOL)suspend {
    [self.operationQueue setSuspended:suspend];

    if (suspend == NO) {
        [self _runNextOperationIfExists];
    }
}

- (void)cancelAllOperations {
    @synchronized(self) {
        [[self.pendingOperations copy] makeObjectsPerformSelector:@selector(cancel)];
        [[self.runningOperations copy] makeObjectsPerformSelector:@selector(cancel)];
    }
}

- (void)cancelAndRunOutAllPendingOperations {
    [self cancelAllOperations];

    for (NSOperation *operation in self.pendingOperations) {
        [self.operationQueue addOperation:operation];
    }
}

#pragma mark
#pragma mark Private

- (void)_runNextOperationIfExists {
    if (self.isSuspended) return;

    @synchronized(self) {
        if (self.pendingOperations.count > 0 && (self.runningOperations.count < self.maxConcurrentOperationCount || (self.maxConcurrentOperationCount == NSOperationQueueDefaultMaxConcurrentOperationCount))) {
            NSUInteger firstReadyOperationIndex = [self.pendingOperations indexOfObjectPassingTest:^BOOL(NSOperation *operation, NSUInteger idx, BOOL *stop) {
                if (operation.isReady) {
                    *stop = YES;

                    return YES;
                } else {
                    return NO;
                }
            }];

            if (firstReadyOperationIndex != NSNotFound) {
                NSOperation *operation = [self.pendingOperations objectAtIndex:firstReadyOperationIndex];

                [operation addObserver:self
                            forKeyPath:@"isFinished"
                               options:NSKeyValueObservingOptionNew
                               context:NULL];
                [operation addObserver:self
                            forKeyPath:@"isExecuting"
                               options:NSKeyValueObservingOptionNew
                               context:NULL];
                [operation addObserver:self
                            forKeyPath:@"isCancelled"
                               options:NSKeyValueObservingOptionNew
                               context:NULL];

                [self.pendingOperations removeObjectAtIndex:firstReadyOperationIndex];
                [self.runningOperations addObject:operation];

                [self.operationQueue addOperation:operation];
            };
        }
    }
}

#pragma mark
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    @synchronized(self) {
        if ([keyPath isEqualToString:@"isFinished"]) {
            [object removeObserver:self forKeyPath:@"isFinished"];
            [object removeObserver:self forKeyPath:@"isExecuting"];
            [object removeObserver:self forKeyPath:@"isCancelled"];

            [self.runningOperations removeObject:object];

            if ([self.delegate respondsToSelector:@selector(operationQueueController:operationDidFinish:)]) {
                [self.delegate operationQueueController:self operationDidFinish:object];
            }
        }

        else if ([keyPath isEqualToString:@"isExecuting"]) {
            if ([self.delegate respondsToSelector:@selector(operationQueueController:operationDidStartExecuting:)]) {
                [self.delegate operationQueueController:self operationDidStartExecuting:object];
            }
        }

        else if ([keyPath isEqualToString:@"isCancelled"]) {
            if ([self.delegate respondsToSelector:@selector(operationQueueController:operationDidCancel:)]) {
                [self.delegate operationQueueController:self operationDidCancel:object];
            }
        }
    }

    [self _runNextOperationIfExists];
}

#pragma mark
#pragma mark NSObject

- (NSString *)description {
    NSString *description;

    @synchronized(self) {
        description = [NSString stringWithFormat:@"%@ (\n\tisSuspended = %@,\n\toperationCount = %u,\n\tpendingOperations = %@,\n\trunningOperations = %@,\n)", super.description, self.isSuspended ? @"YES" : @"NO", (unsigned)self.operationCount, self.pendingOperations, self.runningOperations];
    }

    return description;
}

- (NSString *)debugDescription {
    return self.description;
}

@end
