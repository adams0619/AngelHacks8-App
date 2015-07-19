//
//  CDTQQuerySqlTranslator.m
//
//  Created by Michael Rhodes on 03/10/2014.
//  Copyright (c) 2014 Cloudant. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CDTQQuerySqlTranslator.h"

#import "CDTQQueryExecutor.h"
#import "CDTQIndexManager.h"
#import "CDTQLogging.h"
#import "CDTQQueryValidator.h"

@interface CDTQTranslatorState : NSObject

@property (nonatomic) BOOL atLeastOneIndexUsed;     // if NO, need to generate a return all query
@property (nonatomic) BOOL atLeastOneIndexMissing;  // i.e., we need to use posthoc matcher

@end

@implementation CDTQQueryNode

@end

@implementation CDTQChildrenQueryNode

- (instancetype)init
{
    self = [super init];
    if (self) {
        _children = [NSMutableArray array];
    }
    return self;
}

@end

@implementation CDTQAndQueryNode

@end

@implementation CDTQOrQueryNode

@end

@implementation CDTQSqlQueryNode

@end

@implementation CDTQTranslatorState

@end

@implementation CDTQQuerySqlTranslator

static NSString *const AND = @"$and";
static NSString *const OR = @"$or";
static NSString *const EQ = @"$eq";
static NSString *const EXISTS = @"$exists";

+ (CDTQQueryNode *)translateQuery:(NSDictionary *)query
                     toUseIndexes:(NSDictionary *)indexes
                indexesCoverQuery:(BOOL *)indexesCoverQuery
{
    CDTQTranslatorState *state = [[CDTQTranslatorState alloc] init];

    CDTQQueryNode *node =
        [CDTQQuerySqlTranslator translateQuery:query toUseIndexes:indexes state:state];

    // If we haven't used a single index, we need to return a query
    // which returns every document, so the posthoc matcher can
    // run over every document to manually carry out the query.
    if (!state.atLeastOneIndexUsed) {
        NSSet *neededFields = [NSSet setWithObject:@"_id"];
        NSString *allDocsIndex =
            [CDTQQuerySqlTranslator chooseIndexForFields:neededFields fromIndexes:indexes];

        if (!allDocsIndex) {
            LogError(@"No indexes defined, cannot execute query for all documents");
            return nil;
        }

        NSString *tableName = [CDTQIndexManager tableNameForIndex:allDocsIndex];

        NSString *sql = @"SELECT _id FROM %@;";
        sql = [NSString stringWithFormat:sql, tableName];
        CDTQSqlParts *parts = [CDTQSqlParts partsForSql:sql parameters:@[]];

        CDTQSqlQueryNode *sqlNode = [[CDTQSqlQueryNode alloc] init];
        sqlNode.sql = parts;

        CDTQAndQueryNode *root = [[CDTQAndQueryNode alloc] init];
        [root.children addObject:sqlNode];

        *indexesCoverQuery = NO;
        return root;
    } else {
        *indexesCoverQuery = !state.atLeastOneIndexMissing;
        return node;
    }
}

+ (CDTQQueryNode *)translateQuery:(NSDictionary *)query
                     toUseIndexes:(NSDictionary *)indexes
                            state:(CDTQTranslatorState *)state
{
    // At this point we will have a root compound predicate, AND or OR, and
    // the query will be reduced to a single entry:
    // @{ @"$and": @[ ... predicates (possibly compound) ... ] }
    // @{ @"$or": @[ ... predicates (possibly compound) ... ] }

    CDTQChildrenQueryNode *root;
    NSArray *clauses;

    if (query[AND]) {
        clauses = query[AND];
        root = [[CDTQAndQueryNode alloc] init];
    } else if (query[OR]) {
        clauses = query[OR];
        root = [[CDTQOrQueryNode alloc] init];
    }

    //
    // First handle the simple @"field": @{ @"$operator": @"value" } clauses. These are
    // handled differently for AND and OR parents, so we need to have the conditional
    // logic below.
    //

    NSMutableArray *basicClauses = [NSMutableArray array];

    [clauses enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary *clause = (NSDictionary *)obj;
        NSString *field = clause.allKeys[0];
        if (![field hasPrefix:@"$"]) {
            [basicClauses addObject:clauses[idx]];
        }
    }];

    if (query[AND]) {
        // For an AND query, we require a single compound index and we generate a
        // single SQL statement to use that index to satisfy the clauses.

        NSString *chosenIndex =
            [CDTQQuerySqlTranslator chooseIndexForAndClause:basicClauses fromIndexes:indexes];
        if (!chosenIndex) {
            state.atLeastOneIndexMissing = YES;

            LogWarn(@"No single index contains all of %@; add index for these fields to "
                    @"query efficiently.",
                    basicClauses);
        } else {
            state.atLeastOneIndexUsed = YES;

            // Execute SQL on that index with appropriate values
            CDTQSqlParts *select = [CDTQQuerySqlTranslator selectStatementForAndClause:basicClauses
                                                                            usingIndex:chosenIndex];

            if (!select) {
                LogError(@"Error generating SELECT clause for %@", basicClauses);
                return nil;
            }

            CDTQSqlQueryNode *sql = [[CDTQSqlQueryNode alloc] init];
            sql.sql = select;

            [root.children addObject:sql];
        }

    } else if (query[OR]) {
        // OR nodes require a query for each clause.
        //
        // We want to allow OR clauses to use separate indexes, unlike for AND, to allow
        // users to query over multiple indexes during a single query. This prevents users
        // having to create a single huge index just because one query in their application
        // requires it, slowing execution of all the other queries down.
        //
        // We could optimise for OR parts where we have an appropriate compound index,
        // but we don't for now.

        for (NSDictionary *clause in basicClauses) {
            NSArray *wrappedClause = @[ clause ];

            NSString *chosenIndex =
                [CDTQQuerySqlTranslator chooseIndexForAndClause:wrappedClause fromIndexes:indexes];
            if (!chosenIndex) {
                state.atLeastOneIndexMissing = YES;

                LogWarn(@"No single index contains all of %@; add index for these fields to "
                        @"query efficiently.",
                        basicClauses);
            } else {
                state.atLeastOneIndexUsed = YES;

                // Execute SQL on that index with appropriate values
                CDTQSqlParts *select =
                    [CDTQQuerySqlTranslator selectStatementForAndClause:wrappedClause
                                                             usingIndex:chosenIndex];

                if (!select) {
                    LogError(@"Error generating SELECT clause for %@", basicClauses);
                    return nil;
                }

                CDTQSqlQueryNode *sql = [[CDTQSqlQueryNode alloc] init];
                sql.sql = select;

                [root.children addObject:sql];
            }
        }
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
            CDTQQueryNode *orNode = [CDTQQuerySqlTranslator translateQuery:clauses[idx]
                                                              toUseIndexes:indexes
                                                                     state:state];
            [root.children addObject:orNode];
        }
    }];

    // Add subclauses that are AND
    [clauses enumerateObjectsUsingBlock:^void(id obj, NSUInteger idx, BOOL *stop) {
        NSDictionary *clause = (NSDictionary *)obj;
        NSString *field = clause.allKeys[0];
        if ([field hasPrefix:@"$and"]) {
            CDTQQueryNode *andNode = [CDTQQuerySqlTranslator translateQuery:clauses[idx]
                                                               toUseIndexes:indexes
                                                                      state:state];
            [root.children addObject:andNode];
        }
    }];

    return root;
}

#pragma mark Process single AND clause with no sub-clauses

+ (NSArray *)fieldsForAndClause:(NSArray *)clause
{
    NSMutableArray *fieldNames = [NSMutableArray array];
    for (NSDictionary *term in clause) {
        if (term.count == 1) {
            [fieldNames addObject:term.allKeys[0]];
        }
    }
    return [NSArray arrayWithArray:fieldNames];
}

+ (NSString *)chooseIndexForAndClause:(NSArray *)clause fromIndexes:(NSDictionary *)indexes
{
    NSSet *neededFields = [NSSet setWithArray:[self fieldsForAndClause:clause]];

    if (neededFields.count == 0) {
        LogError(@"Invalid clauses in $and clause %@", clause);
        return nil;  // no point in querying empty set of fields
    }

    return [CDTQQuerySqlTranslator chooseIndexForFields:neededFields fromIndexes:indexes];
}

+ (NSString *)chooseIndexForFields:(NSSet *)neededFields fromIndexes:(NSDictionary *)indexes
{
    NSString *chosenIndex = nil;
    for (NSString *indexName in indexes) {
        NSSet *providedFields = [NSSet setWithArray:indexes[indexName][@"fields"]];
        if ([neededFields isSubsetOfSet:providedFields]) {
            chosenIndex = indexName;
            break;
        }
    }

    return chosenIndex;
}

+ (CDTQSqlParts *)wherePartsForAndClause:(NSArray *)clause
{
    if (clause.count == 0) {
        return nil;  // no point in querying empty set of fields
    }

    // @[@{@"fieldName": @"mike"}, ...]

    NSMutableArray *sqlClauses = [NSMutableArray array];
    NSMutableArray *sqlParameters = [NSMutableArray array];
    NSDictionary *operatorMap = @{
        @"$eq" : @"=",
        @"$gt" : @">",
        @"$gte" : @">=",
        @"$lt" : @"<",
        @"$lte" : @"<=",
        @"$ne" : @"!="
    };

    // We apply these if the clause is negated, along with the NULL clause
    NSDictionary *notOperatorMap = @{
        @"$eq" : @"!=",
        @"$gt" : @"<=",
        @"$gte" : @"<",
        @"$lt" : @">=",
        @"$lte" : @">",
        @"$ne" : @"="
    };
    for (NSDictionary *component in clause) {
        if (component.count != 1) {
            LogError(@"Expected single predicate per clause dictionary, got %@", component);
            return nil;
        }

        NSString *fieldName = component.allKeys[0];
        NSDictionary *predicate = component[fieldName];

        if (predicate.count != 1) {
            LogError(@"Expected single operator per predicate dictionary, got %@", component);
            return nil;
        }

        NSString *operator= predicate.allKeys[0];

        // $not specifies the opposite operator OR NULL documents be returned
        if ([operator isEqualToString:@"$not"]) {
            NSDictionary *negatedPredicate = predicate[@"$not"];

            if (negatedPredicate.count != 1) {
                LogError(@"Expected single operator per predicate dictionary, got %@", component);
                return nil;
            }

            NSString *operator= negatedPredicate.allKeys[0];
            NSObject *predicateValue = nil;

            if([operator isEqualToString:EXISTS]){
                // what we do here depends on the value of the exists are
                predicateValue = [negatedPredicate objectForKey:operator];

                BOOL exists = ![(NSNumber *)predicateValue boolValue];
                // since this clause is negated we need to negate the bool value
                [sqlClauses
                    addObject:[self convertExistsToSqlClauseForFieldName:fieldName exists:exists]];
                    [sqlParameters addObject:[negatedPredicate objectForKey:operator]];

            } else {
                NSString *sqlOperator = notOperatorMap[operator];

                if (!sqlOperator) {
                    LogError(@"Unsupported comparison operator %@", operator);
                    return nil;
                }

                NSString *sqlClause = [NSString stringWithFormat:@"(\"%@\" %@ ? OR \"%@\" IS NULL)",
                                                                 fieldName, sqlOperator, fieldName];
                predicateValue = [negatedPredicate objectForKey:operator];

                [sqlParameters addObject:predicateValue];
                [sqlClauses addObject:sqlClause];
            }

        } else {
            if ([operator isEqualToString:EXISTS]){
                    BOOL  exists = [(NSNumber *)predicate[operator] boolValue];
                    [sqlClauses addObject:[self convertExistsToSqlClauseForFieldName:fieldName
                                                                              exists:exists]];
                    [sqlParameters addObject:[predicate objectForKey:operator]];

            } else {
                NSString *sqlOperator = operatorMap[operator];

                if (!sqlOperator) {
                    LogError(@"Unsupported comparison operator %@", operator);
                    return nil;
                }

                NSString *sqlClause =
                    [NSString stringWithFormat:@"\"%@\" %@ ?", fieldName, sqlOperator];
                [sqlClauses addObject:sqlClause];
                NSObject * predicateValue = [predicate objectForKey:operator];
                if ([self validatePredicateValue:predicateValue]) {
                    [sqlParameters addObject:predicateValue];
                } else {
                    return nil;
                }
            }
        }
    }

    return [CDTQSqlParts partsForSql:[sqlClauses componentsJoinedByString:@" AND "]
                          parameters:sqlParameters];
}

+ (NSString *)convertExistsToSqlClauseForFieldName:(NSString *)fieldName exists:(BOOL)exists
{
    NSString *sqlClause;
    if (exists) {
        // so this field needs to exist
        sqlClause = [NSString stringWithFormat:@"(\"%@\" IS NOT NULL)", fieldName];
    } else {
        // must not exist
        sqlClause = [NSString stringWithFormat:@"(\"%@\" IS NULL)", fieldName];
    }
    return sqlClause;
}

+ (BOOL)validatePredicateValue:(NSObject *)predicateValue
{
    return (([predicateValue isKindOfClass:[NSString class]] ||
             [predicateValue isKindOfClass:[NSNumber class]]));
}

+ (CDTQSqlParts *)selectStatementForAndClause:(NSArray *)clause usingIndex:(NSString *)indexName
{
    if (clause.count == 0) {
        return nil;  // no query here
    }

    if (!indexName) {
        return nil;
    }

    CDTQSqlParts *where = [CDTQQuerySqlTranslator wherePartsForAndClause:clause];

    if (!where) {
        return nil;
    }

    NSString *tableName = [CDTQIndexManager tableNameForIndex:indexName];

    NSString *sql = @"SELECT _id FROM %@ WHERE %@;";
    sql = [NSString stringWithFormat:sql, tableName, where.sqlWithPlaceholders];

    CDTQSqlParts *parts = [CDTQSqlParts partsForSql:sql parameters:where.placeholderValues];
    return parts;
}

@end
