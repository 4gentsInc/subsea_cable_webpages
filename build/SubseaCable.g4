// Subsea Cable syntax projection. See LANGUAGE_REFERENCE.md for authoring.
// Grammar recognition alone does not establish Runtime compatibility.

grammar SubseaCable;

tokens { MULTIPLICITY_ARROW, ROOT, ROOT_ARITY }

program
    : TERMINATOR? statementList EOF
    ;

statementList
    : statement (TERMINATOR statement)* TERMINATOR?
    ;

statement
    : rootDeclaration
    | binding
    | expression
    ;

rootDeclaration
    : ROOT goalName '/' ROOT_ARITY
    ;

binding
    : IDENTIFIER '=' functionLeafImplementation
    | IDENTIFIER '=' declaredGoalArrow
    | IDENTIFIER '=' expression
    ;

functionLeafImplementation
    : fnParams '->' fnBody
    ;

declaredGoalArrow
    : goalParams MULTIPLICITY_ARROW goalBody
    ;

expression
    : goalArrow
    | logicalOr
    ;

goalArrow
    : goalParams '->' goalBody
    ;

goalBody
    : policyPrefix* goalBodyCore
    ;

goalBodyCore
    : goalReference
    | hostAnchor
    | goalArrow
    | serialPipeline
    | parallelComposition
    | resolvingMap
    ;

goalReference
    : goalName (bracketSuffix | callSuffix)
    ;

goalName
    : IDENTIFIER HASH_QUALIFIER?
    ;

policyPrefix
    : '@' IDENTIFIER callSuffix?
    ;

hostAnchor
    : '$' IDENTIFIER callSuffix?
    ;

goalParams
    : '[' (paramList | scopeDestructure)? ']'
    ;

fnParams
    : '(' (paramList | scopeDestructure)? ')'
    ;

fnBody
    : expression
    | functionComposite
    ;

functionComposite
    : '{' expression ';' expression (';' expression)* ';'? '}'
    ;

paramList
    : param (',' param)* ','?
    ;

param
    : IDENTIFIER
    ;

scopeDestructure
    : '{' destructureFieldList? '}'
    ;

destructureFieldList
    : IDENTIFIER (',' IDENTIFIER)* ','?
    ;

logicalOr
    : logicalAnd ('||' logicalAnd)*
    ;

logicalAnd
    : equality ('&&' equality)*
    ;

equality
    : comparison (('==' | '!=') comparison)?
    ;

comparison
    : additive (('<=' | '>=' | '<' | '>') additive)?
    ;

additive
    : multiplicative (('+' | '-') multiplicative)*
    ;

multiplicative
    : unary (('*' | '/' | '%') unary)*
    ;

unary
    : '!' unary
    | '-' unary
    | policyValue
    | postfix
    ;

policyValue
    : policyPrefix+ (goalName (bracketSuffix | callSuffix) | hostAnchor)
    ;

postfix
    : goalName (bracketSuffix | callSuffix)?
    | hostAnchor
    | nonIdentifierPrimary
    ;

bracketSuffix
    : '[' argList? ']'
    ;

callSuffix
    : '(' argList? ')'
    ;

argList
    : expression (',' expression)* ','?
    ;

nonIdentifierPrimary
    : serialPipeline
    | parallelComposition
    | map
    | group
    | NUMBER
    | BOOLEAN
    | STRING_LITERAL
    ;

serialPipeline
    : '[' (pipelineStageList | conditionalStage) ']'
    ;

pipelineStageList
    : goalStage ',' goalStage (',' goalStage)* ','?
    ;

conditionalStage
    : logicalOr ',' conditionalBranchMap ','?
    ;

conditionalBranchMap
    : '{' conditionalBranchEntry (',' conditionalBranchEntry)* ','? '}'
    ;

conditionalBranchEntry
    : mapKey ':' goalStage
    ;

goalStage
    : policyPrefix* goalStageCore
    ;

goalStageCore
    : goalName (bracketSuffix | callSuffix)?
    | hostAnchor
    | goalArrow
    | serialPipeline
    | parallelComposition
    ;

parallelComposition
    : '{' goalStage ',' goalStage (',' goalStage)* ','? '}'
    ;

resolvingMap
    : '{' resolvingMapEntry (',' resolvingMapEntry)* ','? '}'
    ;

resolvingMapEntry
    : mapKey ':' goalStage
    ;

map
    : '{' mapEntryList? '}'
    ;

mapEntryList
    : mapEntry (',' mapEntry)* ','?
    ;

mapEntry
    : mapKey ':' expression
    ;

mapKey
    : '-'? NUMBER
    | BOOLEAN
    | WILDCARD
    | STRING_LITERAL
    | IDENTIFIER
    ;

group
    : '(' expression ')'
    ;

WILDCARD : '_';

HASH_QUALIFIER
    : '#' [a-zA-Z0-9]+
    ;

BOOLEAN
    : 'true'
    | 'false'
    ;

IDENTIFIER
    : IDENT_START IDENT_REST*
    ;

fragment IDENT_START : [a-zA-Z_];
fragment IDENT_REST  : [a-zA-Z0-9_];

NUMBER
    : INT_PART FRAC_PART?
    ;

fragment INT_PART  : '0' | [1-9] [0-9]*;
fragment FRAC_PART : '.' [0-9]+;

STRING_LITERAL
    : '"' STRING_CHAR* '"'
    ;

fragment STRING_CHAR
    : ~["\\\r\n]
    | ESCAPE_SEQ
    ;

fragment ESCAPE_SEQ
    : '\\' ['"nrt\\]
    | '\\u{' HEX_DIGIT HEX_DIGIT? HEX_DIGIT? HEX_DIGIT? HEX_DIGIT? HEX_DIGIT? '}'
    ;

fragment HEX_DIGIT : [0-9a-fA-F];

TERMINATOR

    : ( '\n' | '\r\n' )+
    ;

WHITESPACE
    : [ \t]+ -> channel(HIDDEN)
    ;

LINE_COMMENT

    : '//' ~[\r\n]* -> channel(HIDDEN)
    ;

BLOCK_COMMENT

    : '/*' .*? '*/' -> channel(HIDDEN)
    ;
