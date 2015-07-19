//
//  CDTQQueryValidator.m
//  Pods
//
//  Created by Rhys Short on 06/11/2014.
//
//

#import "CDTQQueryValidator.h"
#import "CDTQLogging.h"

@implementation CDTQQueryValidator

static const NSString *AND = @"$and";
static const NSString *OR = @"$or";
static const NSString *EQ = @"$eq";

+ (NSDictionary *)normaliseAndValidateQuery:(NSDictionary *)query
{
    bool isWildCard = [query count] == 0;

    // First expand the query to include a leading compound predicate
    // if there isn't one already.
    query = [CDTQQueryValidator addImplicitAnd:query];

    // At this point we will have a single entry dict, key AND or OR,
    // forming the compound predicate.
    // Next make sure all the predicates have an operator -- the EQ
    // operator is implicit and we need to add it if there isn't one.
    // Take
    //     @[ @{"field1": @"mike"}, ... ]
    // and make
    //     @[ @{"field1": @{ @"$eq": @"mike"} }, ... } ]
    NSString *compoundOperator = [query allKeys][0];
    NSArray *predicates = query[compoundOperator];
    if ([predicates isKindOfClass:[NSArray class]]) {
        predicates = [CDTQQueryValidator addImplicitEq:predicates];
    }

    NSDictionary *selector = @{compoundOperator : predicates};
    if (isWildCard) {
        return selector;
    } else if ([CDTQQueryValidator validateSelector:selector]) {
        return selector;
    }

    return nil;
}

#pragma mark Normalization methods
+ (NSDictionary *)addImplicitAnd:(NSDictionary *)query
{
    // query is:
    //  either @{ @"field1": @"value1", ... } -- we need to add $and
    //  or     @{ @"$and": @[ ... ] } -- we don't
    //  or     @{ @"$or": @[ ... ] } -- we don't

    if (query.count == 1 && (query[AND] || query[OR])) {
        return query;
    } else {
        // Take
        //     @{"field1": @"mike", ...}
        //     @{"field1": @[ @"mike", @"bob" ], ...}
        // and make
        //     @[ @{"field1": @"mike"}, ... ]
        //     @[ @{"field1": @[ @"mike", @"bob" ]}, ... ]

        NSMutableArray *andClause = [NSMutableArray array];
        for (NSString *k in query) {
            NSObject *predicate = query[k];
            [andClause addObject:@{k : predicate}];
        }
        return @{AND : [NSArray arrayWithArray:andClause]};
    }
}

+ (NSArray *)addImplicitEq:(NSArray *)andClause
{
    NSMutableArray *accumulator = [NSMutableArray array];

    for (NSDictionary *fieldClause in andClause) {
        // fieldClause is:
        //  either @{ @"field1": @"mike"} -- we need to add the $eq operator
        //  or     @{ @"field1": @{ @"$operator": @"value" } -- we don't
        //  or     @{ @"$and": @[ ... ] } -- we don't
        //  or     @{ @"$or": @[ ... ] } -- we don't
        NSObject *predicate = nil;
        NSString *fieldName = nil;
        // if this isn't a dictionary, we don't know what to do so pass it back
        if ([fieldClause isKindOfClass:[NSDictionary class]] && [fieldClause count] != 0) {
            fieldName = fieldClause.allKeys[0];
            predicate = fieldClause[fieldName];
        } else {
            [accumulator addObject:fieldClause];
            continue;
        }

        // If the clause isn't a special clause (the field name starts with
        // $, e.g., $and), we need to check whether the clause already
        // has an operator. If not, we need to add the implicit $eq.
        if (![fieldName hasPrefix:@"$"]) {
            if (![predicate isKindOfClass:[NSDictionary class]]) {
                predicate = @{EQ : predicate};
            }
        } else if ([predicate isKindOfClass:[NSArray class]]) {
            predicate = [CDTQQueryValidator addImplicitEq:(NSArray *)predicate];
        }

        [accumulator addObject:@{fieldName : predicate}];  // can't put nil in this
    }

    return [NSArray arrayWithArray:accumulator];
}

#pragma validation class methods

+ (BOOL)validateCompoundOperatorClauses:(NSArray *)clauses
{
    BOOL valid = NO;

    for (id obj in clauses) {
        valid = NO;
        if (![obj isKindOfClass:[NSDictionary class]]) {
            LogError(@"Operator argument must be a dictionary %@", [clauses description]);
            break;
        }
        NSDictionary *clause = (NSDictionary *)obj;
        if ([clause count] != 1) {
            LogError(@"Operator argument clause should only have one key value pair: %@",
                     [clauses description]);
            break;
        }

        NSString *key = [obj allKeys][0];
        if ([@[ @"$or", @"$not", @"$and" ] containsObject:key]) {
            // this should have an array as top level type
            id compundClauses = [obj objectForKey:key];
            if ([CDTQQueryValidator validateCompoundOperatorOperand:compundClauses]) {
                // validate array
                valid = [CDTQQueryValidator validateCompoundOperatorClauses:compundClauses];
            }
        } else if (![key hasPrefix:@"$"]) {
            // this should have a dict
            // send this for validation
            valid = [CDTQQueryValidator validateClause:[obj objectForKey:key]];
        } else {
            LogError(@"%@ operator cannot be a top level operator", key);
            break;
        }

        if (!valid) {
            break;  // if we have gotten here with valid being no, we should abort
        }
    }

    return valid;
}

+ (BOOL)validateClause:(NSDictionary *)clause
{
    //$exits lt

    NSArray *validOperators =
        @[ @"$eq", @"$lt", @"$gt", @"$exists", @"$not", @"$ne", @"$gte", @"$lte" ];

    if ([clause count] == 1) {
        NSString *operator= [clause allKeys][0];

    if ([validOperators containsObject:operator]) {
        // contains correct operator
        id clauseOperand = [clause objectForKey:[clause allKeys][0]];
        // handle special case, $notis the only op that expects a dict
        if ([operator isEqualToString:@"$not"] && [clauseOperand isKindOfClass:[NSDictionary class]]) {
            return [CDTQQueryValidator validateClause:clauseOperand];

        } else if ([CDTQQueryValidator validatePredicateValue:clauseOperand
                                                  forOperator:[clause allKeys][0]]) {
            return YES;
        }
    }
    }

    return NO;
}

+ (BOOL)validatePredicateValue:(NSObject *)predicateValue forOperator:(NSString *) operator
{
    if([operator isEqualToString:@"$exists"]){
        return [CDTQQueryValidator validateExistsArgument:predicateValue];
    } else {
        return (([predicateValue isKindOfClass:[NSString class]] ||
                 [predicateValue isKindOfClass:[NSNumber class]]));
    }
}

+ (BOOL)validateExistsArgument:(NSObject *)exists
{
    BOOL valid = YES;

    if (![exists isKindOfClass:[NSNumber class]]) {
        valid = NO;
        LogError(@"$exists operator expects YES or NO");
    }

    return valid;
}

+ (BOOL)validateCompoundOperatorOperand:(NSObject *)operand
{
    if (![operand isKindOfClass:[NSArray class]]) {
        LogError(@"Arugment to compound operator is not an NSArray: %@", [operand description]);
        return NO;
    }
    return YES;
}

// we are going to need to walk the query tree to validate it before executing it
// this isn't going to be fun :'(

+ (BOOL)validateSelector:(NSDictionary *)selector
{
    // after normalising we should have a few top level selectors

    NSString *topLevelOp = [selector allKeys][0];

    // top level op can only be $and after normalisation

    if ([@[ @"$and", @"$or" ] containsObject:topLevelOp]) {
        // top level should be $and or $or they should have arrays
        id topLevelArg = [selector objectForKey:topLevelOp];

        if ([topLevelArg isKindOfClass:[NSArray class]]) {
            // safe we know its an NSArray
            return [CDTQQueryValidator validateCompoundOperatorClauses:topLevelArg];
        }
    }
    return NO;
}

@end
