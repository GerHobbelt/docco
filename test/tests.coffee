
{spawn, exec} = require 'child_process'
path          = require 'path'
fs            = require 'fs'

# Determine the test and resources paths
testPath      = path.dirname fs.realpathSync(__filename)
dataPath      = path.join testPath, "data"
resourcesPath = path.normalize path.join(testPath,"/../resources")

# Run a Docco pass and check that the number of output files
# is equal to what is expected.
testDoccoRun = (testName,sources,options={},callback=null) ->
  destPath = path.join dataPath, testName
  cleanup = (callback) -> exec "rm -rf #{destPath}", callback
  cleanup ->
    options?.output = destPath
    Docco.document sources, options, ->
      files       = []
      files       = files.concat(Docco.resolveSource(src)) for src in sources
      expected    = files.length + 1
      found       = fs.readdirSync(destPath).length
      eq found, expected, "find expected output (#{expected} files) - (#{found})"
      callback() if callback?

# **Custom jst template files should be supported**
test "custom JST template file", ->
  testDoccoRun "custom_jst", 
    ["#{testPath}/*.coffee"],
    template: "#{resourcesPath}/pagelet.jst"

# **Custom CSS files should be supported**
test "custom CSS file", ->
  testDoccoRun "custom_css", 
    ["#{testPath}/*.coffee"],
    css: "#{resourcesPath}/pagelet.css"

# **Language specific special files should be supported**
#  
# Some languages have special file names associated with them that may not match 
# the same extension as normal files of that language.  Docco should support
# documenting files of this type.
#  
# Iterate over each file contained in the `special` subdirectory of the `testPath`
# and be sure that Docco correctly identifies their type based on name.
test "language-specific special file names", ->
  specialPath = path.join testPath, "special" 
  files = fs.readdirSync specialPath
  for file in files
    filePath = path.join specialPath, file 
    testDoccoRun "special_#{file}", [filePath]  


# **Comments should be parsed properly**
#  
# There are special data files located in `test/comments` for each supported 
# language.  The first comment in  each file corresponds to the expected number 
# of comments to be parsed from its contents.
#  
# This test iterates over all the known Docco languages, and tests the ones 
# that have a corresponding data file in `test/comments`.
test "single line comment parsing", ->
  commentsPath = path.join testPath, "comments"
  options           = template: "#{commentsPath}/comments.jst"
  languageKeys = (ext for ext,l of Docco.languages)

  testNextLanguage = (keys,callback) ->
    return callback?() if not keys.length

    extension       = keys.shift()
    language        = Docco.languages[extension]
    languageExample = path.join commentsPath, "#{language.name}#{extension}"
    languageTest    = "comments_test/#{language.name}"
    languagePath    = path.join dataPath, languageTest
    languageOutput  = path.join languagePath, "#{language.name}.html"

    # *Skip over this language if there is no corresponding test*
    return testNextLanguage(keys, callback) if not path.existsSync languageExample   
   
    testDoccoRun languageTest, [languageExample], options, ->
      eq true, path.existsSync(languageOutput), "#{languageOutput} -> output file created properly"

      content = fs.readFileSync(languageOutput).toString()
      comments = (c.trim() for c in content.split(',') when c.trim() != '') 

      eq true, comments.length >= 1, 'expect at least the descriptor comment'

      expected = parseInt(comments[0])    
      
      eq comments.length, expected, [
        ""
        "#{path.basename(languageOutput)} comments"
        "------------------------"
        " expected : #{expected}"
        " found    : #{comments.length}"
      ].join '\n'
      
      testNextLanguage keys, callback
      
  # *Kick off the first language test*
  testNextLanguage languageKeys.slice()
     
# **URL references should resolve across sections**
#  
# Resolves [Issue 100](https://github.com/jashkenas/docco/issues/100)
test "url references", ->
  exec "mkdir -p #{dataPath}", ->
    sourceFile = "#{dataPath}/_urlref.coffee"
    fs.writeFileSync sourceFile, [
      "# Look at this link to [Google][]!",
      "console.log 'This must be Thursday.'",
      "# And this link to [Google][] as well.",
      "console.log 'I never could get the hang of Thursdays.'",
      "# [google]: http://www.google.com"
    ].join('\n')
    outPath = path.join dataPath, "_urlreferences"
    outFile = "#{outPath}/_urlref.html"
    exec "rm -rf #{outPath}", ->
      Docco.document [sourceFile], output: outPath, ->
        contents = fs.readFileSync(outFile).toString()
        count = contents.match ///<a\shref="http://www.google.com">Google</a>///g
        eq count.length, 2, "find expected (2) resolved url references"
# **Paths should be recursively created if needed**
#  
# ensureDirectory should properly create complex output paths.
test "create complex paths that do not exist", ->
  exist = fs.existsSync or path.existsSync
  outputPath = path.join dataPath, 'complex/path/that/doesnt/exist'
  exec "rm -rf #{outputPath}", ->
    Docco.ensureDirectory outputPath, ->
      equal exist(outputPath), true, 'created output path'
      stat = fs.statSync outputPath
      equal stat.isDirectory(), true, "target is directory"
