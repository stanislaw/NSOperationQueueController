
#import <SenTestingKit/SenTestingKit.h>

#import "TestHelpers.h"

#import "NSOperationQueueController.h"
#import "NSOperationQueueController_Private.h"

@interface NSOperationQueueControllerTests : SenTestCase
@end

static dispatch_semaphore_t waitSemaphore;

static int finishedOperationsCount;

@interface KeyValueObserver : NSObject
@end

@implementation KeyValueObserver

+ (instancetype)sharedObserver {
    static KeyValueObserver *sharedObserver;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedObserver = [[self alloc] init];
    });

    return sharedObserver;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {

    @synchronized(self) {
        if ([keyPath isEqual:@"isFinished"]) {
            BOOL finished = (BOOL)[[change objectForKey:NSKeyValueChangeNewKey] integerValue];

            if (finished == YES) {
                [object removeObserver:self forKeyPath:@"isFinished"];
                finishedOperationsCount++;
            }
        }
    }
}

@end

SPEC_BEGIN(NSOperationQueueControllerSpecs)
beforeEach(^{
    finishedOperationsCount = 0;
});

describe(@"", ^{
    it(@"", ^{
        __block BOOL isFinished = NO;

        NSOperationQueue *operationQueue = [NSOperationQueue new];

        NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];
        [controller addOperationWithBlock:^{
            isFinished = YES;
        }];

        while(isFinished == NO || controller.runningOperations.count != 0) {}

        [[theValue(isFinished) should] beYes];
        [[theValue(controller.runningOperations.count) should] equal:@(0)];
    });
});

describe(@"", ^{
    it(@"", ^{
        finishedOperationsCount = 0;

        int N = 100;

        NSMutableArray *countArr = [NSMutableArray array];

        NSOperationQueue *operationQueue = [NSOperationQueue new];
        NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];

        int countDown = N;

        while (countDown-- > 0) {
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                @synchronized(countArr) {
                    [countArr addObject:@1];
                }

            }];

            [operation addObserver:[KeyValueObserver sharedObserver]
                        forKeyPath:@"isFinished"
                           options:NSKeyValueObservingOptionNew
                           context:NULL];

            [controller.operationQueue addOperation:operation];
        }

        while (finishedOperationsCount < N) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, NO);
            NSLog(@"%@", controller.operationQueue.operations);
        }
        
        [[theValue(countArr.count) should] equal:@(N)];
        [[theValue(finishedOperationsCount) should] equal:@(N)];
    });
});

describe(@"", ^{
    it(@"", ^{
        NSMutableArray *countArr = [NSMutableArray array];
        __block BOOL finished = NO;

        NSOperationQueue *operationQueue = [NSOperationQueue new];
        operationQueue.maxConcurrentOperationCount = 1;

        NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];

        int countDown = 10;
        while (countDown-- > 0 ) {
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                [[theValue(controller.runningOperations.count) should] equal:@(1)];

                @synchronized(countArr) {
                    [countArr addObject:@1];
                }

                if (countArr.count == 10) {
                    finished = YES;
                }
            }];

            [controller.pendingOperations addObject:operation];
        }
        
        [controller _runNextOperationIfExists];
        
        while (finished == NO);
        
        [[theValue(countArr.count) should] equal:@(10)];

        [[theValue(finished) should] beYes];

    });
});

describe(@"", ^{
    it(@"", ^{
        __block BOOL isFinished = NO;

        NSOperationQueue *operationQueue = [NSOperationQueue new];
        operationQueue.maxConcurrentOperationCount = 1;

        NSOperationQueueController *controller = [[NSOperationQueueController alloc] initWithOperationQueue:operationQueue];
        controller.order = NSOperationQueueControllerOrderAggressiveLIFO;

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
        
        while(isFinished == NO) CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, NO);
        
        
        [[theValue(isFinished) should] beYes];
    });
});


SPEC_END

