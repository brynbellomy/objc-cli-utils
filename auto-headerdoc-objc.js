#!/usr/bin/env /usr/local/bin/node

/* params for user to define if needed */
var currentFramework = null
var currentNamespace = null

/* regexes */
var regex_objcMethod = /(([+-]) ?(\([a-zA-Z0-9 \*]+\)) ?([^{]+);)/g
var regext_objcMethodParams = /[+-] ?\([a-zA-Z0-9 \*]+\) ?(P<params>[^{]+);/g
var regex_objcStripMethodReturnType = /^[+-] ?\([a-zA-Z0-9 _\*]+\) ?/g
var regex_objcStripMethodNamePiecesAndTypes = /\([a-zA-Z0-9 \*_]+\)[a-zA-Z_]+ ?;?/g
var regex_objcStripAllButParamNames = / ?[a-zA-Z_]+:\([a-zA-Z0-9 \*_]+\)/g
var regex_objcProperty = /(@property .* \*?([a-zA-Z0-9_]*);)/g
var regex_objcInterface = /(@interface ([a-zA-Z0-9_]+)[^\n{]* ?{?)/g

function getObjCMethodParamNames(line) {
  return line.replace(regex_objcStripMethodReturnType, '')
             .replace(regex_objcStripAllButParamNames, ':')
             .replace(';', '')
             .split(':')
             .slice(1)
}

function getObjCMethodHeaderdoc(line) {
  var namespaceLine = "@namespace " + currentNamespace
  var headerDoc = "\n/*! \n" +            //"* @" + currentType + " " + name + " \n" + // this is no longer needed in headerdoc 8
                  "* @abstract ??\n" +
                  "* @discussion ??\n"
  
  var paramNames = getObjCMethodParamNames(line)
  for (var i in paramNames)
    headerDoc += "* @param " + paramNames[i] + " Discussion.\n"
                  
  headerDoc +=    "* @throws ??\n" +
                  (currentNamespace != null ? "\n* @namespace " + currentNamespace + "\n" : "") + 
                  "* @updated " + new Date().toDateString() + "\n" +
                  "*/\n$1"

  return headerDoc
}

function getObjCPropertyHeaderdoc(line) {
  return "/*! @property $2 Discussion goes here. */\n$1"
}

function getObjCInterfaceHeaderdoc(line) {
  return "/*!\n" +
         "* @interface $2\n" +
         "* @abstract The abstract.\n" +
         "* @discussion Discussion of this interface.\n" +
         "*/\n" +
         "$1"
}

function getSource(callback) {
  var source = ''
  process.stdin.resume()
  process.stdin.on('data', function(data) {
    source += data
  })
  process.stdin.on('end', function() {
    source = source.split("\n")
    callback(source)
  })
}

getSource(function(source) {
  var processed = []
  
  for (line in source) {
    var original = source[line]
    var theRegex = null
    var generateHeaderdoc = null
    
    if (source[line].indexOf('@property') == 0) {
      theRegex = regex_objcProperty
      generateHeaderdoc = getObjCPropertyHeaderdoc
    }
    else if (source[line].indexOf('- (') == 0 || source[line].indexOf('-(') == 0 || source[line].indexOf('+ (') == 0 || source[line].indexOf('+(') == 0) {
      theRegex = regex_objcMethod
      generateHeaderdoc = getObjCMethodHeaderdoc
    }
    else if (source[line].indexOf('@interface') == 0) {
      theRegex = regex_objcInterface
      generateHeaderdoc = getObjCInterfaceHeaderdoc
    }
      
    if (theRegex != null)
      processed.push(source[line].replace(theRegex, generateHeaderdoc(source[line])));
    else
      processed.push(source[line])
  }

  require('util').puts(processed.join("\n"))
})
