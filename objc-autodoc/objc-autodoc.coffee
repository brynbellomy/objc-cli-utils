
file = ""

process.stdin.on "data", (chunk) -> file += chunk.toString()
process.stdin.on "end", -> processFile file
  

do process.stdin.resume
process.stdin.setEncoding "utf8"



processFile = (code) ->
  lines = code.split "\n"
  processed = []

  for line, i in lines
    processedLine = line

    if processedLine.charAt(0) in ["+", "-"]
      methodDeclaration = [ processedLine ]

      if "{" not in processedLine
        j = 0
        until lines[ i + (++j) ].indexOf("{") isnt -1
          methodDeclaration.push lines[ i + j ]

        if lines[ i + j ].indexOf("{") isnt -1
          methodDeclaration.push lines[ i + j ].slice(0, lines[i + j].indexOf("{"))

      methodDeclaration = methodDeclaration.join " "
      methodDeclaration = methodDeclaration.slice 0, methodDeclaration.indexOf("{")
      processed.push documentationCommentFor methodDeclaration

    processed.push processedLine

  processed = processed.join "\n"
  console.log processed


documentationCommentFor = (methodDeclaration) ->
  #if methodDeclaration.indexOf("initWithForm") isnt -1 then console.log methodDeclaration
  regex_returnType = ///
    [-+]\s*               # + or -
    \(\s*                 # opening (
      ([a-zA-Z0-9_]+)\s*  # the return type
      (\**)?              # possibly '*' for pointers
    \)\s*                 # closing )
  ///

  regex_param = ///
     ([a-zA-Z0-9]+)\s*                  # the param name
     (
       (:)\s*                           # capture the param colon for reconstructing the selector
           \(\s*
            ([a-zA-Z0-9<>]+)\s*         # the type of the param
            (\*?)\s*                    # ... including the '*' for pointers
          \)\s*
       ([a-zA-Z0-9]+)\s*                # the name of the param's local variable
     )?
  ///g

  methodDeclaration = methodDeclaration.replace /\n/, ""

  returnType   = methodDeclaration.slice(methodDeclaration.indexOf("(") + 1, methodDeclaration.indexOf(")")).replace(" ", "")
  methodParams = methodDeclaration.slice(methodDeclaration.indexOf(")") + 1)

  selector = methodParams.replace(regex_param, "$1$3") #\n").split("\n").join(":")
  params   = []

  # if there are actually params, construct @param declarations
  matchedParams = methodParams.match regex_param
  if matchedParams?.length > 0 and matchedParams?[0]?.indexOf?(":") isnt -1
    params = methodParams.replace(regex_param, "@param {$4$5} $6\n").split("\n")

  comment = []
  comment.push "#### " + selector.trim()        # add a markdown h4 tag
  comment.push ""
  comment.push param.trim() for param in params
  comment.push "@return {#{returnType.trim()}}"

  (comment[i] = " * #{line}") for line, i in comment

  "/**!\n" + comment.join("\n") + "\n */\n"


