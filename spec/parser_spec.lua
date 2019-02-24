require 'busted.runner'()

local assert = require 'utils.assert'
local euluna_parser = require 'euluna.parsers.euluna_parser'
local euluna_grammar = euluna_parser.grammar
local euluna_astshape = euluna_parser.astshape
local AST = function(...) return euluna_astshape:create(...) end

describe("Euluna should parse", function()

--------------------------------------------------------------------------------
-- empty file
--------------------------------------------------------------------------------
it("empty file", function()
  assert.parse_ast(euluna_parser, "", AST('Block', {}))
  assert.parse_ast(euluna_parser, " \t\n", AST('Block', {}))
  assert.parse_ast(euluna_parser, ";", AST('Block', {}))
end)

--------------------------------------------------------------------------------
-- invalid syntax
--------------------------------------------------------------------------------
it("invalid syntax", function()
  assert.parse_ast_error(euluna_parser, [[something]], 'UnexpectedSyntaxAtEOF')
end)

--------------------------------------------------------------------------------
-- shebang
--------------------------------------------------------------------------------
it("shebang", function()
  assert.parse_ast(euluna_parser, [[#!/usr/bin/env lua]], AST('Block', {}))
  assert.parse_ast(euluna_parser, [[#!/usr/bin/env lua\n]], AST('Block', {}))
end)

--------------------------------------------------------------------------------
-- comments
--------------------------------------------------------------------------------
it("comments", function()
  assert.parse_ast(euluna_parser, [=[-- line comment
--[[
multiline comment
]]]=], AST('Block', {}))
end)

--------------------------------------------------------------------------------
-- return statement
--------------------------------------------------------------------------------
describe("return", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "return",
      AST('Block', {
        AST('StatReturn', {})
    }))
  end)
  it("with semicolon", function()
    assert.parse_ast(euluna_parser, "return;",
      AST('Block', {
        AST('StatReturn', {})
    }))
  end)
  it("with value", function()
    assert.parse_ast(euluna_parser, "return 0",
      AST('Block', {
        AST('StatReturn', {
          AST('Number', 'int', '0')
    })}))
  end)
  it("with multiple values", function()
    assert.parse_ast(euluna_parser, "return 1,2,3",
      AST('Block', {
        AST('StatReturn', {
          AST('Number', 'int', '1'),
          AST('Number', 'int', '2'),
          AST('Number', 'int', '3'),
    })}))
  end)
end)

--------------------------------------------------------------------------------
-- expressions
--------------------------------------------------------------------------------
describe("expression", function()
  it("number", function()
    assert.parse_ast(euluna_parser, "return 3.34e-50, 0xff, 0.1",
      AST('Block', {
        AST('StatReturn', {
          AST('Number', 'exp', '3.34', '-50'),
          AST('Number', 'hex', 'ff'),
          AST('Number', 'dec', '0.1'),
    })}))
  end)
  it("string", function()
    assert.parse_ast(euluna_parser, [[return 'hi', "there"]],
      AST('Block', {
        AST('StatReturn', {
          AST('String', 'hi'),
          AST('String', 'there')
    })}))
  end)
  it("boolean", function()
    assert.parse_ast(euluna_parser, "return true, false",
      AST('Block', {
        AST('StatReturn', {
          AST('Boolean', true),
          AST('Boolean', false)
    })}))
  end)
  it("nil", function()
    assert.parse_ast(euluna_parser, "return nil",
      AST('Block', {
        AST('StatReturn', {
          AST('Nil'),
    })}))
  end)
  it("varargs", function()
    assert.parse_ast(euluna_parser, "return ...",
      AST('Block', {
        AST('StatReturn', {
          AST('Varargs'),
    })}))
  end)
  it("identifier", function()
    assert.parse_ast(euluna_parser, "return a, _b",
      AST('Block', {
        AST('StatReturn', {
          AST('Id', 'a'),
          AST('Id', '_b'),
    })}))
  end)
  it("table", function()
    assert.parse_ast(euluna_parser, "return {}, {a}, {a,b}, {a=b}, {[a] = b}",
      AST('Block', {
        AST('StatReturn', {
          AST('Table', {}),
          AST('Table', { AST('Id', 'a') }),
          AST('Table', { AST('Id', 'a'), AST('Id', 'b') }),
          AST('Table', { AST('Pair', 'a', AST('Id', 'b')) }),
          AST('Table', { AST('Pair', AST('Id', 'a'), AST('Id', 'b')) }),
    })}))
  end)
  it("surrounded parethesis", function()
    assert.parse_ast(euluna_parser, "return (a)",
      AST('Block', {
        AST('StatReturn', {
          AST('Id', 'a'),
    })}))
  end)
  it("dot index", function()
    assert.parse_ast(euluna_parser, "return a.b, a.b.c",
      AST('Block', {
        AST('StatReturn', {
          AST('DotIndex', 'b',
            AST('Id', 'a')
          ),
          AST('DotIndex', 'c',
            AST('DotIndex', 'b',
              AST('Id', 'a')
          ))
    })}))
  end)
  it("array index", function()
    assert.parse_ast(euluna_parser, "return a[b], a[b][c]",
      AST('Block', {
        AST('StatReturn', {
          AST('ArrayIndex',
            AST('Id', 'b'),
            AST('Id', 'a')
          ),
          AST('ArrayIndex',
            AST('Id', 'c'),
            AST('ArrayIndex',
              AST('Id', 'b'),
              AST('Id', 'a')
          ))
    })}))
  end)
  it("anonymous function", function()
    assert.parse_ast(euluna_parser, "return function() end, function(a, b: B): C,D end",
      AST('Block', {
        AST('StatReturn', {
          AST('Function', nil, nil, AST('Block', {})),
          AST('Function',
            { AST('TypedId', 'a'), AST('TypedId', 'b', AST('Type', 'B')) },
            { AST('Type', 'C'), AST('Type', 'D') },
            AST('Block', {})
          )
    })}))
  end)
  it("call global", function()
    assert.parse_ast(euluna_parser, "return a()",
      AST('Block', {
        AST('StatReturn', {
          AST('Call', {}, {}, AST('Id', 'a')),
    })}))
  end)
  it("call with arguments", function()
    assert.parse_ast(euluna_parser, "return a(a, 'b', 1, f(), ...)",
      AST('Block', {
        AST('StatReturn', {
          AST('Call', {}, {
            AST('Id', 'a'),
            AST('String', 'b'),
            AST('Number', 'int', '1'),
            AST('Call', {}, {}, AST('Id', 'f')),
            AST('Varargs'),
          }, AST('Id', 'a')),
    })}))
  end)
  it("call field", function()
    assert.parse_ast(euluna_parser, "return a.b()",
      AST('Block', {
        AST('StatReturn', {
          AST('Call', {}, {}, AST('DotIndex', 'b', AST('Id', 'a'))),
    })}))
  end)
  it("call method", function()
    assert.parse_ast(euluna_parser, "return a:b()",
      AST('Block', {
        AST('StatReturn', {
          AST('CallMethod', 'b', {}, {}, AST('Id', 'a')),
    })}))
  end)
end)

--------------------------------------------------------------------------------
-- tables
--------------------------------------------------------------------------------
describe("table", function()
  it("complex fields", function()
    assert.parse_ast(euluna_parser, [[return {
      a=a, [a]=a, [nil]=nil, [true]=true,
      ['mystr']='mystr', [1.0]=1.0, [func()]=func(),
      [...]=...
    }]],
      AST('Block', {
        AST('StatReturn', {
          AST('Table', {
            AST('Pair', 'a', AST('Id', 'a')),
            AST('Pair', AST('Id', 'a'), AST('Id', 'a')),
            AST('Pair', AST('Nil'), AST('Nil')),
            AST('Pair', AST('Boolean', true), AST('Boolean', true)),
            AST('Pair', AST('String', 'mystr'), AST('String', 'mystr')),
            AST('Pair', AST('Number', 'dec', '1.0'), AST('Number', 'dec', '1.0')),
            AST('Pair', AST('Call', {}, {}, AST('Id', 'func')), AST('Call', {}, {}, AST('Id', 'func'))),
            AST('Pair', AST('Varargs'), AST('Varargs')),
    })})}))
  end)
  it("multiple values", function()
    assert.parse_ast(euluna_parser, "return {a,nil,true,'mystr',1.0,func(),...}",
      AST('Block', {
        AST('StatReturn', {
          AST('Table', {
            AST('Id', 'a'),
            AST('Nil'),
            AST('Boolean', true),
            AST('String', 'mystr'),
            AST('Number', 'dec', '1.0'),
            AST('Call', {}, {}, AST('Id', 'func')),
            AST('Varargs'),
    })})}))
  end)
  it("nested", function()
    assert.parse_ast(euluna_parser, "return {{{}}}",
      AST('Block', {
        AST('StatReturn', {
          AST('Table', { AST('Table', { AST('Table', {})}),
    })})}))
  end)
end)


--------------------------------------------------------------------------------
-- call statement
--------------------------------------------------------------------------------
describe("call", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "a()",
      AST('Block', {
        AST('Call', {}, {}, AST('Id', 'a')),
    }))
  end)
  it("dot index", function()
    assert.parse_ast(euluna_parser, "a.b()",
      AST('Block', {
        AST('Call', {}, {}, AST('DotIndex', 'b', AST('Id', 'a')))
    }))
  end)
  it("array index", function()
    assert.parse_ast(euluna_parser, "a['b']()",
      AST('Block', {
        AST('Call', {}, {}, AST('ArrayIndex', AST('Id', 'b'), AST('Id', 'a')))
    }))
  end)
  it("method", function()
    assert.parse_ast(euluna_parser, "a:b()",
      AST('Block', {
        AST('CallMethod', 'b', {}, {}, AST('Id', 'a'))
    }))
  end)
  it("typed", function()
    assert.parse_ast(euluna_parser, "print<string>('hi')",
      AST('Block', {
        AST('Call',
          { AST('Type', 'string') },
          { AST('String', 'hi') },
          AST('Id', 'print')),
    }))
  end)
  it("typed method", function()
    assert.parse_ast(euluna_parser, "s:substr<number,number>(1,2)",
      AST('Block', {
        AST('CallMethod',
          'substr',
          { AST('Type', 'number'), AST('Type', 'number') },
          { AST('Number', 'int', '1'), AST('Number', 'int', '2') },
          AST('Id', 's')
    )}))
  end)
end)

--------------------------------------------------------------------------------
-- if statement
--------------------------------------------------------------------------------
describe("statement if", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "if true then end",
      AST('Block', {
        AST('StatIf', {
          {AST('Boolean', true), AST('Block', {})}
    })}))
  end)
  it("with elseifs and else", function()
    assert.parse_ast(euluna_parser, "if a then return x elseif b then return y else return z end",
      AST('Block', {
        AST('StatIf', {
          { AST('Id', 'a'), AST('Block', {AST('StatReturn', { AST('Id', 'x') })}) },
          { AST('Id', 'b'), AST('Block', {AST('StatReturn', { AST('Id', 'y') })}) },
        },
        AST('Block', {AST('StatReturn', { AST('Id', 'z') })})
    )}))
  end)
end)

--------------------------------------------------------------------------------
-- switch statement
--------------------------------------------------------------------------------
describe("statement switch", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "switch a case b then end",
      AST('Block', {
        AST('StatSwitch',
          AST('Id', 'a'),
          { {AST('Id', 'b'), AST('Block', {})} }
    )}))
  end)
  it("multiple cases", function()
    assert.parse_ast(euluna_parser, "switch a case b then case c then else end",
      AST('Block', {
        AST('StatSwitch',
          AST('Id', 'a'),
          { {AST('Id', 'b'), AST('Block', {})},
            {AST('Id', 'c'), AST('Block', {})}
          },
          AST('Block', {})
    )}))
  end)
end)

--------------------------------------------------------------------------------
-- do statement
--------------------------------------------------------------------------------
describe("statement do", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "do end",
      AST('Block', {
        AST('StatDo', AST('Block', {}))
    }))
  end)
  it("with statements", function()
    assert.parse_ast(euluna_parser, "do print() end",
      AST('Block', {
        AST('StatDo', AST('Block', { AST('Call', {}, {}, AST('Id', 'print')) }))
    }))
  end)
end)

--------------------------------------------------------------------------------
-- simple loop statements
--------------------------------------------------------------------------------
describe("loop statement", function()
  it("while", function()
    assert.parse_ast(euluna_parser, "while a do end",
      AST('Block', {
        AST('StatWhile', AST('Id', 'a'), AST('Block', {}))
    }))
  end)
  it("break and continue", function()
    assert.parse_ast(euluna_parser, "while a do break end",
      AST('Block', {
        AST('StatWhile', AST('Id', 'a'), AST('Block', { AST('StatBreak') }))
    }))
    assert.parse_ast(euluna_parser, "while a do continue end",
      AST('Block', {
        AST('StatWhile', AST('Id', 'a'), AST('Block', { AST('StatContinue') }))
    }))
  end)
  it("repeat", function()
    assert.parse_ast(euluna_parser, "repeat until a",
      AST('Block', {
        AST('StatRepeat', AST('Block', {}), AST('Id', 'a'))
    }))
    assert.parse_ast(euluna_parser, "repeat print() until a==b",
      AST('Block', {
        AST('StatRepeat',
          AST('Block', { AST('Call', {}, {}, AST('Id', 'print')) }),
          AST('BinaryOp', 'eq', AST('Id', 'a'), AST('Id', 'b'))
    )}))
  end)
end)

--------------------------------------------------------------------------------
-- for statement
--------------------------------------------------------------------------------
describe("statement for", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "for i=1,10 do end",
      AST('Block', {
        AST('StatForNum',
          AST('TypedId', 'i'),
          AST('Number', 'int', '1'),
          'le',
          AST('Number', 'int', '10'),
          nil,
          AST('Block', {}))
    }))
  end)
  it("reverse with comparations", function()
    assert.parse_ast(euluna_parser, "for i:number=10,>0,-1 do end",
      AST('Block', {
        AST('StatForNum',
          AST('TypedId', 'i', AST('Type', 'number')),
          AST('Number', 'int', '10'),
          'gt',
          AST('Number', 'int', '0'),
          AST('UnaryOp', 'neg', AST('Number', 'int', '1')),
          AST('Block', {}))
    }))
  end)
  it("in", function()
    assert.parse_ast(euluna_parser, "for i in iter do end",
      AST('Block', {
        AST('StatForIn',
          { AST('TypedId', 'i') },
          AST('Id', 'iter'),
          AST('Block', {}))
    }))
  end)
  it("in typed", function()
    assert.parse_ast(euluna_parser, "for i:int8,j:int16,k:int32 in iter() do end",
      AST('Block', {
        AST('StatForIn',
          { AST('TypedId', 'i', AST('Type', 'int8')),
            AST('TypedId', 'j', AST('Type', 'int16')),
            AST('TypedId', 'k', AST('Type', 'int32'))
          },
          AST('Call', {}, {}, AST('Id', 'iter')),
          AST('Block', {}))
    }))
  end)
end)

--------------------------------------------------------------------------------
-- goto statement
--------------------------------------------------------------------------------
describe("statement goto", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "goto mylabel",
      AST('Block', {
        AST('StatGoto', 'mylabel')
    }))
  end)
  it("label", function()
    assert.parse_ast(euluna_parser, "::mylabel::",
      AST('Block', {
        AST('StatLabel', 'mylabel')
    }))
  end)
  it("complex", function()
    assert.parse_ast(euluna_parser, "::mylabel:: f() if a then goto mylabel end",
      AST('Block', {
        AST('StatLabel', 'mylabel'),
        AST('Call', {}, {}, AST('Id', 'f')),
        AST('StatIf', { {AST('Id', 'a'), AST('Block', {AST('StatGoto', 'mylabel')}) } })
    }))
  end)
end)

--------------------------------------------------------------------------------
-- variable declaration statement
--------------------------------------------------------------------------------
describe("statement variable declaration", function()
  it("local variable", function()
    assert.parse_ast(euluna_parser, [[
      local a
      local a: integer
    ]],
      AST('Block', {
        AST('StatVarDecl', 'local', 'var', { AST('TypedId', 'a') }),
        AST('StatVarDecl', 'local', 'var', { AST('TypedId', 'a', AST('Type', 'integer')) })
    }))
  end)
  it("local variable assignment", function()
    assert.parse_ast(euluna_parser, [[
      local a = b
      local a: integer = b
    ]],
      AST('Block', {
        AST('StatVarDecl', 'local', 'var', { AST('TypedId', 'a') }, { AST('Id', 'b') }),
        AST('StatVarDecl', 'local', 'var',
          { AST('TypedId', 'a', AST('Type', 'integer')) },
          { AST('Id', 'b') })
    }))
  end)
  it("global variable", function()
    assert.parse_ast(euluna_parser, "global a",
      AST('Block', {
        AST('StatVarDecl', 'global', 'var', { AST('TypedId', 'a') })
    }))
  end)
  it("variable mutabilities", function()
    assert.parse_ast(euluna_parser, [[
      var a = b
      let a = b
      local ref a = b
      global const a = b
    ]],
      AST('Block', {
        AST('StatVarDecl', 'local', 'var', { AST('TypedId', 'a') }, { AST('Id', 'b') }),
        AST('StatVarDecl', 'local', 'let', { AST('TypedId', 'a') }, { AST('Id', 'b') }),
        AST('StatVarDecl', 'local', 'ref', { AST('TypedId', 'a') }, { AST('Id', 'b') }),
        AST('StatVarDecl', 'global', 'const', { AST('TypedId', 'a') }, { AST('Id', 'b') }),
    }))
  end)
  it("variable multiple assigments", function()
    assert.parse_ast(euluna_parser, "local a,b,c = x,y,z",
      AST('Block', {
        AST('StatVarDecl', 'local', 'var',
          { AST('TypedId', 'a'), AST('TypedId', 'b'), AST('TypedId', 'c') },
          { AST('Id', 'x'), AST('Id', 'y'), AST('Id', 'z') }),
    }))
  end)
end)

--------------------------------------------------------------------------------
-- assignment statement
--------------------------------------------------------------------------------
describe("statement assignment", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "a = b",
      AST('Block', {
        AST('StatAssign',
          { AST('Id', 'a') },
          { AST('Id', 'b') }),
    }))
  end)
  it("multiple", function()
    assert.parse_ast(euluna_parser, "a,b,c = x,y,z",
      AST('Block', {
        AST('StatAssign',
          { AST('Id', 'a'), AST('Id', 'b'), AST('Id', 'c') },
          { AST('Id', 'x'), AST('Id', 'y'), AST('Id', 'z') }),
    }))
  end)
  it("on indexes", function()
    assert.parse_ast(euluna_parser, "a.b, a[b], a[b][c], f(a).b = x,y,z,w",
      AST('Block', {
        AST('StatAssign',
          { AST('DotIndex', 'b', AST('Id', 'a')),
            AST('ArrayIndex', AST('Id', 'b'), AST('Id', 'a')),
            AST('ArrayIndex', AST('Id', 'c'), AST('ArrayIndex', AST('Id', 'b'), AST('Id', 'a'))),
            AST('DotIndex', 'b', AST('Call', {}, {AST('Id', 'a')}, AST('Id', 'f'))),
          },
          { AST('Id', 'x'), AST('Id', 'y'), AST('Id', 'z'), AST('Id', 'w') })
    }))
  end)
end)

--------------------------------------------------------------------------------
-- function statement
--------------------------------------------------------------------------------
describe("statement function", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "function f() end",
      AST('Block', {
        AST('StatFuncDef', nil, 'f', nil, nil, AST('Block', {}) )
    }))
  end)
  it("local and typed", function()
    assert.parse_ast(euluna_parser, "local function f(a, b: int): string end",
      AST('Block', {
        AST('StatFuncDef', 'local', 'f',
          { AST('TypedId', 'a'), AST('TypedId', 'b', AST('Type', 'int')) },
          { AST('Type', 'string') },
          AST('Block', {}) )
    }))
  end)
end)

--------------------------------------------------------------------------------
-- operators
--------------------------------------------------------------------------------
describe("operator", function()
  it("'or'", function()
    assert.parse_ast(euluna_parser, "return a or b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'or', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'and'", function()
    assert.parse_ast(euluna_parser, "return a and b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'and', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'<'", function()
    assert.parse_ast(euluna_parser, "return a < b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'lt', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'>'", function()
    assert.parse_ast(euluna_parser, "return a > b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'gt', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'<='", function()
    assert.parse_ast(euluna_parser, "return a <= b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'le', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'>='", function()
    assert.parse_ast(euluna_parser, "return a >= b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'ge', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'~='", function()
    assert.parse_ast(euluna_parser, "return a ~= b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'ne', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'=='", function()
    assert.parse_ast(euluna_parser, "return a == b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'eq', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'|'", function()
    assert.parse_ast(euluna_parser, "return a | b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'bor', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'~'", function()
    assert.parse_ast(euluna_parser, "return a ~ b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'bxor', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'&'", function()
    assert.parse_ast(euluna_parser, "return a & b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'band', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'<<'", function()
    assert.parse_ast(euluna_parser, "return a << b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'shl', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'>>'", function()
    assert.parse_ast(euluna_parser, "return a >> b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'shr', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'..'", function()
    assert.parse_ast(euluna_parser, "return a .. b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'concat', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'+'", function()
    assert.parse_ast(euluna_parser, "return a + b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'add', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'-'", function()
    assert.parse_ast(euluna_parser, "return a - b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'sub', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'*'", function()
    assert.parse_ast(euluna_parser, "return a * b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'mul', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'/'", function()
    assert.parse_ast(euluna_parser, "return a / b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'div', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'%'", function()
    assert.parse_ast(euluna_parser, "return a % b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'mod', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'not'", function()
    assert.parse_ast(euluna_parser, "return not a",
      AST('Block', {
        AST('StatReturn', {
          AST('UnaryOp', 'not', AST('Id', 'a')
    )})}))
  end)
  it("'#'", function()
    assert.parse_ast(euluna_parser, "return #a",
      AST('Block', {
        AST('StatReturn', {
          AST('UnaryOp', 'len', AST('Id', 'a')
    )})}))
  end)
  it("'-'", function()
    assert.parse_ast(euluna_parser, "return -a",
      AST('Block', {
        AST('StatReturn', {
          AST('UnaryOp', 'neg', AST('Id', 'a')
    )})}))
  end)
  it("'~'", function()
    assert.parse_ast(euluna_parser, "return ~a",
      AST('Block', {
        AST('StatReturn', {
          AST('UnaryOp', 'bnot', AST('Id', 'a')
    )})}))
  end)
  it("'$'", function()
    assert.parse_ast(euluna_parser, "return $a",
      AST('Block', {
        AST('StatReturn', {
          AST('UnaryOp', 'tostring', AST('Id', 'a')
    )})}))
  end)
  it("'^'", function()
    assert.parse_ast(euluna_parser, "return a ^ b",
      AST('Block', {
        AST('StatReturn', {
          AST('BinaryOp', 'pow', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("ternary if", function()
    assert.parse_ast(euluna_parser, "return a if c else b",
      AST('Block', {
        AST('StatReturn', {
          AST('TernaryOp', 'if', AST('Id', 'a'), AST('Id', 'c'), AST('Id', 'b')
    )})}))
  end)
end)

--------------------------------------------------------------------------------
-- operators precedence rules
--------------------------------------------------------------------------------
--[[
Operator precedence in Lua follows the table below, from lower
to higher priority:
  or
  and
  <     >     <=    >=    ~=    ==
  |
  ~
  &
  <<    >>
  ..
  +     -
  *     /     //    %
  unary operators (not   #     -     ~)
  ^
All binary operators are left associative, except for `^´ (exponentiation)
and `..´ (concatenation), which are right associative.
]]
describe("operators following precedence rules for", function()
  --TODO
end)

--------------------------------------------------------------------------------
-- live grammar change
--------------------------------------------------------------------------------
describe("live grammar change for", function()
  it("return keyword", function()
    local grammar = euluna_grammar:clone()
    local parser = euluna_parser:clone()
    parser:add_keyword("do_return")
    grammar:set_pegs([[
      stat_return <-
        ({} %DO_RETURN -> 'StatReturn' {| (expr (%COMMA expr)*)? |} %SEMICOLON?) -> to_astnode
    ]], nil, true)
    parser:set_peg('sourcecode', grammar:build())
    parser:remove_keyword("return")

    assert.parse_ast(parser, "do_return",
      AST('Block', {
        AST('StatReturn', {})}))
    assert.parse_ast_error(parser, "return", 'UnexpectedSyntaxAtEOF')
  end)

  it("return keyword (revert)", function()
    assert.parse_ast(euluna_parser, "return",
      AST('Block', {
        AST('StatReturn', {})}))
    assert.parse_ast_error(euluna_parser, "do_return", 'UnexpectedSyntaxAtEOF')
  end)
end)

end)
