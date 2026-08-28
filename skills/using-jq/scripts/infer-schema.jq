def addtype($node; $t):
  ($node // {}) as $n
  | $n + {
      types: ((($n.types // []) + [$t]) | unique)
    };

def insert($node; $path; $value):
  if ($path | length) == 0 then
    addtype($node; ($value | type))
  else
    $path[0] as $k
    | $path[1:] as $rest
    | if ($k | type) == "number" then
        # Numeric path elements are array indexes.
        # Ignore the actual index and merge all elements into "items".
        ($node // {}) as $n
        | addtype($n; "array")
        | .items = insert(($n.items // null); $rest; $value)
      else
        # String path elements are object properties.
        ($node // {}) as $n
        | addtype($n; "object")
        | .properties[$k] =
            insert(($n.properties[$k] // null); $rest; $value)
      end
  end;

def emit:
  . as $n
  | (
      if (($n.types // []) | length) == 1 then
        {type: $n.types[0]}
      elif (($n.types // []) | length) > 1 then
        {type: $n.types}
      else
        {}
      end
    )
    + (
      if $n.properties then
        {
          properties:
            ($n.properties | with_entries(.value |= emit))
        }
      else
        {}
      end
    )
    + (
      if $n.items then
        {items: ($n.items | emit)}
      else
        {}
      end
    );

reduce (inputs | select(length == 2)) as $event
  (null;
   insert(.; $event[0]; $event[1]))
| {
    "$schema": "https://json-schema.org/draft/2020-12/schema"
  } + emit
