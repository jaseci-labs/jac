with entry {
    a = 4;
    b = 7;
    c = a + b;  # OpExpr.
    d = a + b + c;

    h = float(a);  # CallExpr.

    (1 < 2);  # ComparisonExpr.
    ('a' + 'b').upper();  # CallExpr.
    [1, 2][0];  # IndexExpr.
    not False;  # UnaryExpr.
    "a" if True else "b";  # ConditionalExpr.
    [i for i in range(10)];  # ListComprehension.
}
# Remaining expressions to test:
# AssertTypeExpr,
# AssignmentExpr,
# AwaitExpr,
# BytesExpr,
# CastExpr,
# ComplexExpr,
# DictionaryComprehension,
# DictExpr,
# EllipsisExpr,
# EnumCallExpr,
# Expression,
# FloatExpr,
# GeneratorExpr,
# IntExpr,
# LambdaExpr,
# ListExpr,
# MemberExpr,
# NamedTupleExpr,
# NameExpr,
# NewTypeExpr,
# ParamSpecExpr,
# PromoteExpr,
# RefExpr,
# RevealExpr,
# SetComprehension,
# SetExpr,
# StarExpr,
# StrExpr,
# SuperExpr,
# TupleExpr,
# TypeAliasExpr,
# TypedDictExpr,
# TypeVarExpr,
# TypeVarTupleExpr,
# YieldExpr,
# YieldFromExpr,
