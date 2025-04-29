input_parser = import_module("/src/challenger/input_parser.star")

def test_challenger_input_parser_empty(plan):
    expect.eq(input_parser.parse(None, []), [])
    expect.eq(input_parser.parse({}, []), [])

def test_challenger_input_parser_default_args(plan):
    expect.eq(input_parser.parse({ "challenger": None }, []), [])
    expect.eq(input_parser.parse({ "challenger": {} }, []), [])
