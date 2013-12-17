
#import <SenTestingKit/SenTestingKit.h>

#import "TestHelpers.h"

#import "NSOperationQueueController.h"
#import "NSOperationQueueController_Private.h"

@interface NSOperationQueueControllerTests : SenTestCase
@end

SPEC_BEGIN(NSOperationQueueControllerSpecs)
beforeEach(^{
    finishedOperationsCount = 0;
});

describe(@"", ^{
    it(@"addOperationWithBlock", ^{
        waitSemaphore = dispatch_semaphore_create(0);

        NSOperationQueue *operationQueue = [NSOperationQueue new];

        NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];
        [controller addOperationWithBlock:^{
            dispatch_semaphore_signal(waitSemaphore);
        }];

        while (dispatch_semaphore_wait(waitSemaphore, DISPATCH_TIME_NOW)) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, YES);
        }

        [[theValue(controller.runningOperations.count) should] equal:@(0)];
    });
});

describe(@"KVO observation of isFinished key path", ^{
    it(@"", ^{
        waitSemaphore = dispatch_semaphore_create(0);

        finishedOperationsCount = 0;

        int N = 100;

        NSMutableArray *registry = [NSMutableArray array];

        NSOperationQueue *operationQueue = [NSOperationQueue new];
        NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];

        int countDown = N;

        while (countDown-- > 0) {
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [registry addObject:@(1)];

                    if (registry.count == N) {
                        dispatch_semaphore_signal(waitSemaphore);
                    }
                });
            }];

            [operation addObserver:[KeyValueObserver sharedObserver]
                        forKeyPath:@"isFinished"
                           options:NSKeyValueObservingOptionNew
                           context:NULL];

            [controller.operationQueue addOperation:operation];
        }

        while (dispatch_semaphore_wait(waitSemaphore, DISPATCH_TIME_NOW)) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, YES);
        }
        
        [[theValue(registry.count) should] equal:@(N)];
        [[theValue(finishedOperationsCount) should] equal:@(N)];
    });
});

describe(@"maxConcurrentOperationCount == 1", ^{
    it(@"", ^{
        waitSemaphore = dispatch_semaphore_create(0);

        NSMutableArray *registry = [NSMutableArray array];

        NSOperationQueue *operationQueue = [NSOperationQueue new];
        operationQueue.maxConcurrentOperationCount = 1;

        NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];

        int countDown = 10;
        while (countDown-- > 0 ) {
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                [[theValue(controller.runningOperations.count) should] equal:@(1)];

                dispatch_async(dispatch_get_main_queue(), ^{
                    [registry addObject:@(1)];

                    if (registry.count == 10) {
                        dispatch_semaphore_signal(waitSemaphore);
                    }
                });
            }];

            [controller.pendingOperations addObject:operation];
        }
        
        [controller _runNextOperationIfExists];
        
        while (dispatch_semaphore_wait(waitSemaphore, DISPATCH_TIME_NOW)) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, YES);
        }
        
        [[theValue(registry.count) should] equal:@(10)];
    });
});

describe(@"NSOperationQueueControllerOrderLIFO with limit == 1", ^{
    it(@"", ^{
        __block BOOL isFinished = NO;

        NSOperationQueue *operationQueue = [NSOperationQueue new];
        
        operationQueue.maxConcurrentOperationCount = 1;

        NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];
        controller.order = NSOperationQueueControllerOrderLIFO;
        controller.limit = 1;

        NSBlockOperation *neverFinishOperation = [NSBlockOperation blockOperationWithBlock:^{
            dispatch_semaphore_wait(waitSemaphore, DISPATCH_TIME_FOREVER);
        }];

        NSBlockOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
            // Nothing intentionally - operation will never be run
            // Because it will be replaced by the following operation
            abort();
        }];

        NSBlockOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
            // Nothing intentionally - operation will never be run
            // Because it will be replaced by the following operation

            isFinished = YES;
        }];

        waitSemaphore = dispatch_semaphore_create(0); // Use waitSemaphore to ensure that operation1 and operation2 will be added before neverFinishOperation will finish

        [controller addOperation:neverFinishOperation];
        [controller addOperation:operation1];
        [controller addOperation:operation2];

        dispatch_semaphore_signal(waitSemaphore);
        
        while (isFinished == NO) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, YES);
        }
        
        [[theValue(isFinished) should] beYes];
        [[theValue(operation1.isCancelled) should] beYes];
        [[theValue(operation1.isFinished) should] beYes];
    });
});

describe(@"NSOperationQueueControllerOrderFIFO with limit == 1", ^{
    it(@"", ^{
        __block BOOL isFinished = NO;

        NSOperationQueue *operationQueue = [NSOperationQueue new];

        operationQueue.maxConcurrentOperationCount = 1;

        NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];
        controller.order = NSOperationQueueControllerOrderFIFO;
        controller.limit = 1;

        NSBlockOperation *neverFinishOperation = [NSBlockOperation blockOperationWithBlock:^{
            dispatch_semaphore_wait(waitSemaphore, DISPATCH_TIME_FOREVER);
        }];

        NSBlockOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
            // Nothing intentionally - operation will never be run
            // Because it will be replaced by the following operation
            abort();
        }];

        NSBlockOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
            // Nothing intentionally - operation will never be run
            // Because it will be replaced by the following operation

            isFinished = YES;
        }];

        waitSemaphore = dispatch_semaphore_create(0);

        [controller addOperation:neverFinishOperation];
        [controller addOperation:operation1];
        [controller addOperation:operation2];

        dispatch_semaphore_signal(waitSemaphore);

        while (isFinished == NO) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, YES);
        }

        [[theValue(isFinished) should] beYes];
        [[theValue(operation1.isCancelled) should] beYes];
        [[theValue(operation1.isFinished) should] beYes];
    });
});

describe(@"-[NSOperationQueueController addOperation:]", ^{
    describe(@"With given limit", ^{
        it(@"should remove older operations so pendingOperation.count <= limit", ^{
            NSOperationQueue *operationQueue = [NSOperationQueue new];

            operationQueue.maxConcurrentOperationCount = 0;

            NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];
            controller.order = NSOperationQueueControllerOrderFIFO;
            controller.limit = 2;

            NSBlockOperation *operation1 = [NSBlockOperation blockOperationWithBlock:^{
                // Nothing intentionally - operation will never be run
                // Because it will be replaced by the following operation
                abort();
            }];

            NSBlockOperation *operation2 = [NSBlockOperation blockOperationWithBlock:^{
                // Nothing intentionally - operation will never be run
                // Because it will be replaced by the following operation
                abort();
            }];

            NSBlockOperation *operation3 = [NSBlockOperation blockOperationWithBlock:^{
                // Nothing intentionally - operation will never be run
                // Because it will be replaced by the following operation
                abort();
            }];

            NSBlockOperation *operation4 = [NSBlockOperation blockOperationWithBlock:^{
                // Nothing intentionally - operation will never be run
                // Because it will be replaced by the following operation
                abort();
            }];

            [controller addOperation:operation1];
            [controller addOperation:operation2];
            [controller addOperation:operation3];
            [controller addOperation:operation4];

            BOOL containsOperation3 = [controller.pendingOperations containsObject:operation3];
            BOOL containsOperation4 = [controller.pendingOperations containsObject:operation4];

            [[theValue(controller.pendingOperations.count) should] equal:@(2)];

            [[theValue(containsOperation3) should] beYes];
            [[theValue(containsOperation4) should] beYes];
        });

        it(@"should run as many operations as numberOfPendingOperationsToRun formula allows (number of pending operations with respect to -[NSOperation maxConcurrentOperationCount] and @NSOperationController.limit", ^{
            waitSemaphore = dispatch_semaphore_create(0);

            NSOperationQueue *operationQueue = [NSOperationQueue new];

            operationQueue.maxConcurrentOperationCount = 2;

            NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];
            controller.order = NSOperationQueueControllerOrderFIFO;
            controller.limit = 2;

            NSNeverFinishBlockOperation *operation1 = [NSNeverFinishBlockOperation blockOperationWithBlock:^{
                // Nothing intentionally - operation will never be run
                // Because it will be replaced by the following operation
            }];

            NSNeverFinishBlockOperation *operation2 = [NSNeverFinishBlockOperation blockOperationWithBlock:^{
                dispatch_semaphore_signal(waitSemaphore);
            }];

            NSNeverFinishBlockOperation *operation3 = [NSNeverFinishBlockOperation blockOperationWithBlock:^{
                // Nothing intentionally - operation will never be run
                // Because it will be replaced by the following operation

                abort();
            }];

            NSNeverFinishBlockOperation *operation4 = [NSNeverFinishBlockOperation blockOperationWithBlock:^{
                // Nothing intentionally - operation will never be run
                // Because it will be replaced by the following operation

                abort();
            }];

            [controller addOperation:operation1];
            [controller addOperation:operation2];
            [controller addOperation:operation3];
            [controller addOperation:operation4];

            while (dispatch_semaphore_wait(waitSemaphore, DISPATCH_TIME_NOW)) {
                CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.05, YES);
            }

            [[theValue(controller.pendingOperations.count) should] equal:@(2)];
            [[theValue(controller.runningOperations.count) should] equal:@(2)];

            BOOL containsOperation1 = [controller.runningOperations containsObject:operation1];
            BOOL containsOperation2 = [controller.runningOperations containsObject:operation2];

            BOOL containsOperation3 = [controller.pendingOperations containsObject:operation3];
            BOOL containsOperation4 = [controller.pendingOperations containsObject:operation4];

            [[theValue(containsOperation1) should] beYes];
            [[theValue(containsOperation2) should] beYes];

            [[theValue(containsOperation3) should] beYes];
            [[theValue(containsOperation4) should] beYes];
        });
    });


});


describe(@"numberOfPendingOperationsToRun", ^{
    it(@"should count number of pending operations", ^{
        NSUInteger numberOfPendingOperations = numberOfPendingOperationsToRun(5, 2, NSOperationQueueDefaultMaxConcurrentOperationCount);
        [[theValue(numberOfPendingOperations) should] equal:@(5)];

        numberOfPendingOperations = numberOfPendingOperationsToRun(2, 5, NSOperationQueueDefaultMaxConcurrentOperationCount);
        [[theValue(numberOfPendingOperations) should] equal:@(2)];

        numberOfPendingOperations = numberOfPendingOperationsToRun(2, 2, NSOperationQueueDefaultMaxConcurrentOperationCount);
        [[theValue(numberOfPendingOperations) should] equal:@(2)];

        numberOfPendingOperations = numberOfPendingOperationsToRun(2, 2, 2);
        [[theValue(numberOfPendingOperations) should] equal:@(0)];

        numberOfPendingOperations = numberOfPendingOperationsToRun(2, 2, 2);
        [[theValue(numberOfPendingOperations) should] equal:@(0)];

        numberOfPendingOperations = numberOfPendingOperationsToRun(2, 2, 0);
        [[theValue(numberOfPendingOperations) should] equal:@(0)];

        numberOfPendingOperations = numberOfPendingOperationsToRun(0, 2, NSOperationQueueDefaultMaxConcurrentOperationCount);
        [[theValue(numberOfPendingOperations) should] equal:@(0)];

    });
});

SPEC_END

