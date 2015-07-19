//
//  CDTQUnindexedQuery.m
//  Pods
//
//  Created by Michael Rhodes on 31/10/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTQUnindexedMatcher.h"

#import "CDTQQuerySqlTranslator.h"
#import "CDTQLogging.h"
#import "CDTQValueExtractor.h"
#import "CDTQQueryValidator.h"

#import "CDTDocumentRevision.h"

@implementation CDTQOperatorExpressionNode

@end

@interface CDTQUnindexedMatcher ()

@property (nonatomic, strong) CDTQChildrenQueryNode *root;

@end

@implementation CDTQUnindexedMatcher

static NSString *const AND = @"$and";
static NSString *const OR = @"$or";
static NSString *const NOT = @"$not";

#pragma mark Creating matcher

+ (CDTQUnindexedMatcher *)matcherWithSelector:(NSDictionary *)selector
{
    CDTQChildrenQueryNode *root = [CDTQUnindexedMatcher buildExecutionTreeForSelector:selector];

    if (!root) {
        return nil;
    }

    CDTQUnindexedMatcher *matcher = [[CDTQUnindexedMatcher alloc] init];
    matcher.root = root;
    return matcher;
}

+ (CDTQChildrenQueryNode *)buildExecutionTreeForSelector:(NSDictionary *)selector
{
    // At this point we will have a root compound predicate, AND or OR, and
    // the query will be reduced to a single entry:
    // @{ @"$and": @[ ... predicates (possibly compound) ... ] }
    // @{ @"$or": @[ ... predicates (possibly compound) ... ] }

    CDTQChildrenQueryNode *root;
    NSArray *clauses;

    if (selector[AND]) {
        clauses = selector[AND];
        root = [[CDTQAndQueryNode alloc] init];
    } else if (selector[OR]) {
        clauses = selector[OR];
        root = [[CDTQOrQueryNode alloc] init];
    }

    //
    // First handle the simple @"field": @{ @"$operator": @"value" } clauses.
    //

    NSMutableArray *basicClauses = [NSMutableArray array];

    [clauses enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary *clause = (NSDictionary *)obj;
        NSString *field = clause.allKeys[0];
        if (![field hasPrefix:@"$"]) {
            [basicClauses addObject:clauses[idx]];
        }
    }];

    // Execution step will evaluate each child node and AND or OR the results.
    for (NSDictionary *expression in basicClauses) {
        CDTQOperatorExpressionNode *node = [[CDTQOperatorExpressionNode alloc] init];
        node.expression = expression;
        [root.children addObject:node];
    }

    //
    // AND and OR subclauses are handled identically whatever the parent is.
    // We go through the query twice to order the OR clauses before the AND
    // clauses, for predictability.
    //

    // Add subclauses that are OR
    [clauses enumerateObjectsUsingBlock:^void(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary *clause = (NSDictionary *)obj;
        NSString *field = clause.allKeys[0];
        if ([field hasPrefix:@"$or"]) {
            CDTQQueryNode *orNode =
                [CDTQUnindexedMatcher buildExecutionTreeForSelector:clauses[idx]];
            [root.children addObject:orNode];
        }
    }];

    // Add subclauses that are AND
    [clauses enumerateObjectsUsingBlock:^void(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary *clause = (NSDictionary *)obj;
        NSString *field = clause.allKeys[0];
        if ([field hasPrefix:@"$and"]) {
            CDTQQueryNode *andNode =
                [CDTQUnindexedMatcher buildExecutionTreeForSelector:clauses[idx]];
            [root.children addObject:andNode];
        }
    }];

    return root;
}

#pragma mark Matching documents

- (BOOL)matches:(CDTDocumentRevision *)rev
{
    return [self executeSelectorTree:self.root onRevision:rev];
}

#pragma mark Tree walking

- (BOOL)executeSelectorTree:(CDTQQueryNode *)node onRevision:(CDTDocumentRevision *)rev
{
    if ([node isKindOfClass:[CDTQAndQueryNode class]]) {
        BOOL passed = YES;

        CDTQAndQueryNode *andNode = (CDTQAndQueryNode *)node;

//        if ([andNode.children count] == 0) {
//            // well this isn't right, something has gone wrong
//            return NO;
//        }

        for (CDTQQueryNode *child in andNode.children) {
            passed = passed && [self executeSelectorTree:child onRevision:rev];
        }

        return passed;
    }
    if ([node isKindOfClass:[CDTQOrQueryNode class]]) {
        BOOL passed = NO;

        CDTQOrQueryNode *orNode = (CDTQOrQueryNode *)node;
        for (CDTQQueryNode *child in orNode.children) {
            passed = passed || [self executeSelectorTree:child onRevision:rev];
        }

        return passed;

    } else if ([node isKindOfClass:[CDTQOperatorExpressionNode class]]) {
        NSDictionary *expression = ((CDTQOperatorExpressionNode *)node).expression;

        // Here we could have:
        //   { fieldName: { operator: value } }
        // or
        //   { fieldName: { $not: { operator: value } } }

        // Next evaluate the result
        NSString *fieldName = expression.allKeys[0];
        NSDictionary *operatorExpression = expression[fieldName];

        NSString *operator= operatorExpression.allKeys[0];

        // First work out whether we need to invert the result when done
        BOOL invertResult = [operator isEqualToString:NOT];
        if (invertResult) {
            operatorExpression = operatorExpression[NOT];
            operator= operatorExpression.allKeys[0];
        }

        NSObject *expected = operatorExpression[operator];
        NSObject *actual = [CDTQValueExtractor extractValueForFieldName:fieldName fromRevision:rev];

        BOOL passed = NO;
        // For array actual values, the operator expression is matched
        // if any of the array values match it. We need to be careful
        // to invert the match status of every candidate, rather than
        // just flipping the result at the end.
        //
        // This is because @{ @"$not": @{ @"$eq": @"white_cat" } } needs
        // to be taken as an atomic check, meaning:
        //   "there's an item in the array that matches `!= "white_cat"`"
        // rather than:
        //   "not (there's an item that matches white_cat)"
        // The latter is satisfied using the $nin operator.
        if ([actual isKindOfClass:[NSArray class]]) {
            BOOL currentItemPassed = NO;
            for (NSObject *item in(NSArray *)actual) {
                // OR as any value in the array can match
                currentItemPassed = [self actualValue:item
                                      matchesOperator:operator 
                                     andExpectedValue:expected
                                     ];
                passed = passed || (invertResult ? !currentItemPassed : currentItemPassed);
            }
        } else {
            passed = [self actualValue:actual
                       matchesOperator:operator 
                      andExpectedValue:expected
                      ];
            passed = invertResult ? !passed : passed;
        }

        return passed;

    } else {
        // We constructed the tree, so shouldn't end up here; error if we do.
        LogError(@"Found unexpected selector execution tree: %@", node);
        return NO;
    }
}

- (BOOL)actualValue:(NSObject *)actual
     matchesOperator:(NSString *) operator
    andExpectedValue:(NSObject *)expected
{
    BOOL passed = NO;

    if ([operator isEqualToString:@"$eq"]) {
        passed = [self eqL:actual R:expected];

    } else if ([operator isEqualToString:@"$ne"]) {
        passed = [self neL:actual R:expected];

    } else if ([operator isEqualToString:@"$lt"]) {
        passed = [self ltL:actual R:expected];

    } else if ([operator isEqualToString:@"$lte"]) {
        passed = [self lteL:actual R:expected];

    } else if ([operator isEqualToString:@"$gt"]) {
        passed = [self gtL:actual R:expected];

    } else if ([operator isEqualToString:@"$gte"]) {
        passed = [self gteL:actual R:expected];

    } else if ([operator isEqualToString:@"$exists"]) {
        BOOL expectedBool = [((NSNumber *)expected)boolValue];
        BOOL exists = (actual != nil);
        passed = (exists == expectedBool);

    } else {
        LogWarn(@"Found unexpected operator in selector: %@", operator);
        passed = NO;  // didn't understand
    }

    return passed;
}

#pragma mark matchers

- (BOOL)eqL:(NSObject *)l R:(NSObject *)r { return [l isEqual:r]; }

- (BOOL)neL:(NSObject *)l R:(NSObject *)r { return ![self eqL:l R:r]; }

//
// Try to respect SQLite's ordering semantics:
//  1. NULL
//  2. INT/REAL
//  3. TEXT
//  4. BLOB
- (BOOL)ltL:(NSObject *)l R:(NSObject *)r
{
    if (l == nil) {
        return NO;  // nil fails all lt/gt/lte/gte tests

    } else if (!([l isKindOfClass:[NSString class]] || [l isKindOfClass:[NSNumber class]])) {
        LogWarn(@"Value in document not NSNumber or NSString: %@", l);
        return NO;  // Not sure how to compare values that are not numbers or strings

    } else if ([l isKindOfClass:[NSString class]]) {
        if ([r isKindOfClass:[NSNumber class]]) {
            return NO;  // INT < STRING
        }

        NSString *lStr = (NSString *)l;
        NSString *rStr = (NSString *)r;

        NSComparisonResult result = [lStr compare:rStr];
        return (result == NSOrderedAscending);

    } else if ([l isKindOfClass:[NSNumber class]]) {
        if ([r isKindOfClass:[NSString class]]) {
            return YES;  // INT < STRING
        }

        NSNumber *lNum = (NSNumber *)l;
        NSNumber *rNum = (NSNumber *)r;

        NSComparisonResult result = [lNum compare:rNum];
        return (result == NSOrderedAscending);

    } else {
        return NO;  // Catch all which we cannot reach
    }
}

- (BOOL)lteL:(NSObject *)l R:(NSObject *)r
{
    if (l == nil) {
        return NO;  // nil fails all lt/gt/lte/gte tests
    }

    if (!([l isKindOfClass:[NSString class]] || [l isKindOfClass:[NSNumber class]])) {
        LogWarn(@"Value in document not NSNumber or NSString: %@", l);
        return NO;  // Not sure how to compare values that are not numbers or strings
    }

    return [self ltL:l R:r] || [l isEqual:r];
}

- (BOOL)gtL:(NSObject *)l R:(NSObject *)r
{
    if (l == nil) {
        return NO;  // nil fails all lt/gt/lte/gte tests
    }

    if (!([l isKindOfClass:[NSString class]] || [l isKindOfClass:[NSNumber class]])) {
        LogWarn(@"Value in document not NSNumber or NSString: %@", l);
        return NO;  // Not sure how to compare values that are not numbers or strings
    }

    return ![self lteL:l R:r];
}

- (BOOL)gteL:(NSObject *)l R:(NSObject *)r
{
    if (l == nil) {
        return NO;  // nil fails all lt/gt/lte/gte tests
    }

    if (!([l isKindOfClass:[NSString class]] || [l isKindOfClass:[NSNumber class]])) {
        LogWarn(@"Value in document not NSNumber or NSString: %@", l);
        return NO;  // Not sure how to compare values that are not numbers or strings
    }

    return ![self ltL:l R:r];
}

@end
