Docco
=====

**Docco** is a quick-and-dirty documentation generator, written in
[Literate CoffeeScript](http://coffeescript.org/#literate).
It produces an HTML document that displays your comments intermingled with your
code. All prose is passed through
[Markdown](http://daringfireball.net/projects/markdown/syntax), and code is
passed through [Highlight.js](http://highlightjs.org/) syntax highlighting.
This page is the result of running Docco against its own
[source file](https://github.com/jashkenas/docco/blob/master/docco.litcoffee).

1. Install Docco with **npm**: `sudo npm install -g docco`

2. Run it against your code: `docco src/*.coffee`

There is no "Step 3". This will generate an HTML page for each of the named
source files, with a menu linking to the other pages, saving the whole mess
into a `docs` folder (configurable).

The [Docco source](http://github.com/jashkenas/docco) is available on GitHub,
and is released under the [Lil License](http://lillicense.org/v1.html).

Docco can be used to process code written in any programming language. If it
doesn't handle your favorite yet, feel free to
[add it to the list](https://github.com/jashkenas/docco/blob/master/resources/languages.json).
Finally, the ["literate" style](http://coffeescript.org/#literate) of *any*
language listed in [languages.json](https://github.com/jashkenas/docco/blob/master/resources/languages.json) 
is also supported — just tack an `.md` extension on the end:
`.coffee.md`, `.py.md`, and so on. Also get usable source code by adding the
`--source` option while specifying a directory for the files.

By default only single-line comments are processed, block comments may be included
by passing the `-b` flag to Docco.


Partners in Crime:
------------------

* If **Node.js** doesn't run on your platform, or you'd prefer a more
convenient package, get [Ryan Tomayko](http://github.com/rtomayko)'s
[Rocco](http://rtomayko.github.io/rocco/rocco.html), the **Ruby** port that's
available as a gem. (**WARNING**: project seems currently broken and apparently abandoned.)

* If you're writing shell scripts, try
[Shocco](http://rtomayko.github.io/shocco/), a port for the **POSIX shell**,
also by Mr. Tomayko. (**WARNING**: project seems currently broken and apparently abandoned.)

* If **Python** is more your speed, take a look at
[Pycco](https://pycco-docs.github.io/pycco/), originally developed by
[Nick Fitzgerald](http://github.com/fitzgen) and now maintained by
the [pycco-docs](https://github.com/pycco-docs) community.

* For **Clojure** fans, [Fogus](http://blog.fogus.me/)'s
[Marginalia](http://fogus.me/fun/marginalia/) is a bit of a departure from
"quick-and-dirty", but it'll get the job done.

* There's a **Go** port called [Gocco](http://nikhilm.github.io/gocco/),
written by [Nikhil Marathe](https://github.com/nikhilm).

* For all you **PHP** buffs out there, Fredi Bach's
[sourceMakeup](http://jquery-jkit.com/sourcemakeup/) (we'll let the faux pas
with respect to our naming scheme slide), should do the trick nicely.

* **Lua** enthusiasts can get their fix with
[Robert Gieseke](https://github.com/rgieseke)'s [Locco](http://rgieseke.github.io/locco/).

* And if you happen to be a **.NET**
aficionado, check out [Don Wilson](https://github.com/dontangg)'s
[Nocco](http://dontangg.github.io/nocco/).

* Going further afield from the quick-and-dirty, [Groc](http://nevir.github.io/groc/)
is a **CoffeeScript** fork of Docco that adds a searchable table of contents,
and aims to gracefully handle large projects with complex hierarchies of code.

Note that not all ports will support all Docco features ... yet.


Main Documentation Generation Functions
---------------------------------------

Generate the documentation for our configured source file by copying over static
assets, reading all the source files in, splitting them up into prose+code
sections, highlighting each file in the appropriate language, printing them
out in an HTML template, and writing plain code files where instructed.

    document = (options = {}, user_callback) ->
      config = configure options
      source_infos = []

      fs.mkdirsSync config.output
      fs.mkdirsSync config.source if config.source

      callback = (error) ->
        if error
          user_callback error if user_callback 
          throw error
        if user_callback
          user_callback null, { source_infos, config }

      copyAsset  = (file, callback) ->
        return callback() unless fs.existsSync file
        fs.copy file, path.join(config.output, path.basename(file)), callback
      complete   = ->
        copyAsset config.css, (error) ->
          return callback error if error
          return copyAsset config.public, callback

      files = config.sources.slice()

      nextFile = ->
        source = files.shift()
        fs.readFile source, (error, buffer) ->
          return callback error if error

          code = buffer.toString()
          sections = parse source, code, config
          format source, sections, config

The **title** of the file is either the first heading in the prose, or the
name of the source file.

          firstSection = _.find sections, (section) ->
            section.docsText.length > 0
          first = marked.lexer(firstSection.docsText)[0] if firstSection
          hasTitle = first and first.type is 'heading' and first.depth is 1
          title = if hasTitle then first.text else path.basename source

          source_infos.push({
            source: source,
            hasTitle: hasTitle,
            title: title,
            sections: sections
          })

          if files.length then nextFile() else outputFiles()

When we have finished all preparations (such as extracting a title for each file),
we produce all output files.

We have collected all titles before outputting the individual files to give the
template access to all sources' titles for rendering, e.g. when the template
needs to produce a TOC with each file.

      outputFiles = ->
        for info, i in source_infos
          write info.source, i, source_infos, config
          outputCode info.source, info.sections, i, source_infos, config
        complete()

Start processing all sources and producing the corresponding files for each:

      if files.length then nextFile() else outputFiles()

Given a string of source code, **parse** out each block of prose and the code that
follows it — by detecting which is which, line by line — and then create an
individual **section** for it. Each section is an object with `docsText` and
`codeText` properties, and eventually `docsHtml` and `codeHtml` as well.

    parse = (source, code, config = {}) ->
      lines    = code.split '\n'
      sections = []
      lang     = getLanguage source, config
      hasCode  = docsText = codeText = ''
      param    = ''
      in_block = 0
      ignore_this_block = 0

      save = ->
        sections.push {docsText, codeText}
        hasCode = docsText = codeText = ''

Our quick-and-dirty implementation of the literate programming style. Simply
invert the prose and code relationship on a per-line basis, and then continue as
normal below.

Note: "Literate markdown" is an exception here as it's basically the reverse.

      if lang.literate and lang.name != 'markdown'
        isText = maybeCode = yes
        for line, i in lines
          lines[i] = if maybeCode and match = /^([ ]{4}|[ ]{0,3}\t)/.exec line
            isText = no
            line[match[0].length..]
          else if maybeCode = /^\s*$/.test line
            if isText then lang.symbol else ''
          else
            isText = yes
            lang.symbol + ' ' + line

Iterate over the source lines, and separate out single/block
comments from code chunks.

      for line in lines
        if in_block
          ++in_block

        raw_line = line

If we're not in a block comment, and find a match for the start
of one, eat the tokens, and note that we're now in a block.

        if not in_block and config.blocks and lang.blocks and line.match(lang.commentEnter)
          line = line.replace(lang.commentEnter, '')

Make sure this is a comment that we actually want to process; if not, treat it as code

          in_block = 1
          if lang.commentIgnore and line.match(lang.commentIgnore)
            ignore_this_block = 1

Process the line, marking it as docs if we're in a block comment,
or we find a single-line comment marker.

        single = (not in_block and lang.commentMatcher and line.match(lang.commentMatcher) and not line.match(lang.commentFilter))

If there's a single comment, and we're not in a block, eat the
comment token.

        if single
          line = line.replace(lang.commentMatcher, '')

Make sure this is a comment that we actually want to process; if not, treat it as code

          if lang.commentIgnore and line.match(lang.commentIgnore)
            ignore_this_block = 1

Prepare the line further when it is (part of) a comment line.

        if in_block or single

If we're in a block comment and we find the end of it in the line, eat
the end token, and note that we're no longer in the block.

          if in_block and line.match(lang.commentExit)
            line = line.replace(lang.commentExit, '')
            in_block = -1

If we're in a block comment and are processing comment line 2 or further, eat the
optional comment prefix (for C style comments, that would generally be
a single '*', for example).

          if in_block > 1 and lang.commentNext
            line = line.replace(lang.commentNext, '');

If we happen upon a JavaDoc `@param` parameter, then process that item.

          if lang.commentParam
            param = line.match(lang.commentParam);
            if param
              line = line.replace(param[0], '\n' + '<b>' + param[1] + '</b>');

        if not ignore_this_block and (in_block or single)

If we have code text, and we're entering a comment, store off
the current docs and code, then start a new section.

          save() if hasCode

          docsText += line + '\n'
          save() if /^(---+|===+)$/.test line or in_block == -1

        else
          hasCode = yes
          if config.indent
            oldLen = 0
            while oldLen != line.length
              oldLen = line.length
              line = line.replace(/^(\x20*)\t/, '$1' + config.indent)
          codeText += line + '\n'

Reset `in_block` when we have reached the end of the comment block.

        if in_block == -1
          in_block = 0

Reset `ignore_this_block` when we have reached the end of the comment block or single comment line.

        if not in_block
          ignore_this_block = 0

Save the final section, if any, and return the sections array.

      save()

      sections

To **format** and highlight the now-parsed sections of code, we use **Highlight.js**
over stdio, and run the text of their corresponding comments through
**Markdown**, using [Marked](https://github.com/chjj/marked).

    format = (source, sections, config) ->
      language = getLanguage source, config

Pass any user defined options to Marked if specified via command line option,
otherwise revert use the default configuration.

      markedOptions = config.marked_options

      marked.setOptions markedOptions

Tell Marked how to highlight code blocks within comments, treating that code
as either the language specified in the code block or the language of the file
if not specified.

      marked.setOptions {
        highlight: (code, lang) ->
          lang or= language.name

          if highlightjs.getLanguage(lang)
            highlightjs.highlight(lang, code).value
          else
            console.warn "docco: couldn't highlight code block with unknown language '#{lang}' in #{source}"
            code
      }

Also instruct Marked to run a preliminary scan of all the chunks first, where we want to
collect all link references. Only in the second run will we then require Marked to produce
the final HTML rendered output.

We have to execute this 2-phase process to ensure that any input which includes MarkDown
link references is processed properly: without the initial scan any link reference defined
later (near the end of the input document) will be unknown to document chunks near the top
of the input document.

      marked.setOptions {
        linksCollector: {}
        execPrepPhaseOnly: true
      }

Process each chunk (phase 1):
- both the code and text blocks are stripped of trailing empty lines
- the code block is marked up by highlighted to show a nice HTML rendition of the code
- the text block is fed to Marked for an initial scan

      for section, i in sections
        if language.name == 'markdown'
          if language.literate
            code = section.codeText
            section.codeText = code = code.replace(/\s+$/, '')
            section.codeHtml = marked(code)

            doc = section.docsText
            section.docsText = doc = doc.replace(/\s+$/, '')
            marked(doc)
          else
            section.codeHtml = ''

            code = section.codeText
            section.codeText = code = code.replace(/\s+$/, '')
            marked(code)
        else
          code = section.codeText
          section.codeText = code = code.replace(/\s+$/, '')
          try
            code = highlightjs.highlight(language.name, code).value
          catch err
            throw err unless config.ignore
            code = section.codeText

          section.codeHtml = "<div class='highlight'><pre>#{code}</pre></div>"
          doc = section.docsText
          section.docsText = doc = doc.replace(/\s+$/, '')
          marked(doc)

Process each chunk (phase 2):
- the text block is fed to Marked to turn it into HTML

      marked.setOptions {
        execPrepPhaseOnly: false
      }

      for section, i in sections
        if language.name == 'markdown'
          if language.literate
            doc = section.docsText
            section.docsHtml = marked(doc)
          else
            code = section.codeText
            section.docsHtml = marked(code)
        else
          doc = section.docsText
          section.docsHtml = marked(doc)

Once all of the code has finished highlighting, we can **write** the resulting
documentation file by passing the completed HTML sections into the template,
and rendering it to the specified output path.

    write = (source, title_idx, source_infos, config) ->

      destination = (file) ->
        make_destination config.output, config.separator, file, '.html', config.keepext, config

      destfile = destination source

      relative = (srcfile) ->
        to = path.dirname(path.resolve(srcfile))
        dstfile = destination srcfile
        from = path.dirname(path.resolve(dstfile))
        path.join(path.relative(from, to), path.basename(srcfile))

      css = if config.css then relative path.join(config.output, path.basename(config.css)) else null

      html = config.template {
        sources: config.sources
        titles: source_infos.map (info) ->
          info.title
        css
        title: source_infos[title_idx].title
        hasTitle: source_infos[title_idx].hasTitle
        sections: source_infos[title_idx].sections
        path
        destination
        relative
        language: getLanguage source, config
      }

      console.log "docco: #{source} -> #{destfile}"
      fs.mkdirsSync path.dirname(destfile)
      fs.writeFileSync destfile, html
      source_infos[title_idx].destDocFile = destfile

Print out the consolidated code sections parsed from the source file in to another
file. No documentation will be included in the new file.

    outputCode = (source, sections, title_idx, source_infos, config) ->
      lang = getLanguage source, config

      if config.source
        destfile = make_destination config.source, config.separator, source, lang.source, false, config
      
        code = _.pluck(sections, 'codeText').join '\n'
        code = code.trim().replace /(\n{2,})/g, '\n\n'

        console.log "docco: #{source} -> #{destfile}"
        fs.mkdirsSync path.dirname(destfile)
        fs.writeFileSync destfile, code
        source_infos[title_idx].destCodeFile = destfile


Helper Functions
----------------

To help us produce decent file names and paths for all inputs, we define a few helper functions:

It should not matter if we are running on Windows, Unix or some other platform: we unify all paths
to a single UNIXy format which can be processed easily everywhere (Windows accepts both native and
UNIX path separators).

    normalize = (path) ->
      path.replace(/[\\\/]/g, '/')

We construct a suitable filename/path for each document by prepending it with the specified
relative path while using the separator specified on the command line. (The default separator ('-'
dash) is used to flatten the directory tree when we process a directory tree all at once.)

    qualifiedName = (file, separator, extension, keep_ext, config) ->
      cwd = if config and config.cwd then config.cwd else process.cwd() 
      file = normalize(file)
      nameParts = path.dirname(file).replace(normalize(cwd), '').split('/')
      nameParts.shift() while nameParts[0] is '' or nameParts[0] is '.' or nameParts[0] is '..'
      nameParts.push(if keep_ext then path.basename(file) else path.basename(file, path.extname(file)))

      nameParts.join(separator) + extension

    make_destination = (basepath, separator, file, extension, keep_ext, config) ->
      path.join basepath, qualifiedName(file, separator, extension, keep_ext, config)


Configuration
-------------

Default configuration **options**. All of these may be extended by
user-specified options.

    defaults =
      sources:    []
      layout:     'parallel'
      output:     'docs'
      template:   null
      css:        null
      extension:  null
      languages:  {}
      source:     null
      cwd:        process.cwd()
      separator:  '-'
      blocks:     false
      marked_options: {
        gfm: true,
        tables: true,
        breaks: false,
        pedantic: false,
        sanitize: false,
        smartLists: true,
        smartypants: yes,
        langPrefix: 'language-',
        highlight: (code, lang) ->
          code
      }
      ignore:     false
      keepext:    false
      tabSize:    null
      indent:     null

**Configure** this particular run of Docco. We might use a passed-in external
template, one of the built-in **layouts**, or an external **layout**. We only attempt to process
source files for languages for which we have definitions.

    configure = (options) ->
      config = _.extend {}, defaults, _.pick(options, _.keys(defaults)...)

      config.languages = buildMatchers config.languages

Determine what the indent should be if the user has supplied a custom tab-size
on the command line.

      if config.tabSize
        config.indent = Array(parseInt(config.tabSize) + 1).join(' ')

The user is able to override the layout file used with the `--template` parameter.
In this case, it is also necessary to explicitly specify a stylesheet file.
These custom templates are compiled exactly like the predefined ones, but the `public` folder
is only copied for the latter.

      if options.template
        unless options.css
          console.warn "docco: no stylesheet file specified"
        config.layout = null
      else
        dir = config.layout = if fs.existsSync path.join __dirname, 'resources', config.layout then path.join __dirname, 'resources', config.layout else path.join process.cwd(), config.layout;
        config.public       = path.join dir, 'public' if fs.existsSync path.join dir, 'public'
        config.template     = path.join dir, 'docco.jst'
        config.css          = options.css or path.join dir, 'docco.css'
      config.template = _.template fs.readFileSync(config.template).toString()

When the user specifies custom Marked options in a (JSON-formatted) configuration file,
mix those options which our defaults such that each default option remains active when it has
not been explicitly overridden by the user.

      if options.marked_options
        config.marked_options = _.extend config.marked_options, JSON.parse fs.readFileSync(options.marked_options)

      if options.args
        config.sources = options.args.filter((source) ->
          lang = getLanguage source, config
          console.warn "docco: skipped unknown type (#{path.basename source})" unless lang
          lang
        ).sort()

      config


Helpers & Initial Setup
-----------------------

Require our external dependencies.

    _           = require 'underscore'
    fs          = require 'fs-extra'
    path        = require 'path'
    marked      = require 'marked'
    commander   = require 'commander'
    highlightjs = require '@gerhobbelt/highlight.js'

Languages are stored in JSON in the file `resources/languages.json`.
Each item maps the file extension to the name of the language and the
`symbol` that indicates a line comment. To add support for a new programming
language to Docco, just add it to the file.

    languages = JSON.parse fs.readFileSync(path.join(__dirname, 'resources', 'languages.json'))

Build out the appropriate matchers and delimiters for each language.

    buildMatchers = (languages) ->
      for ext, l of languages

Does the line begin with a comment?

        if (l.symbol)
          l.commentMatcher = ///^\s*#{l.symbol}\s?///

Support block comment parsing?

        if l.enter and l.exit
          l.blocks = true
          l.commentEnter = new RegExp(l.enter)
          l.commentExit = new RegExp(l.exit)
          if (l.next)
            l.commentNext = new RegExp(l.next)
        if l.param
          l.commentParam = new RegExp(l.param)

Ignore [hashbangs](http://en.wikipedia.org/wiki/Shebang_%28Unix%29) and interpolations...

        l.commentFilter = /(^#![/]|^\s*#\{)/

We ignore any comments which start with a colon ':' - these will be included in the code as is.

        l.commentIgnore = new RegExp(/^:/)

      languages
    languages = buildMatchers languages

A function to get the current language we're documenting, based on the
file extension. Detect and tag "literate" `.ext.md` variants.

    getLanguage = (source, config) ->
      ext  = config.extension or path.extname(source) or path.basename(source)
      lang = config.languages?[ext] or languages[ext] or languages['text']
      if lang
        if lang.name is 'markdown'
          codeExt = path.extname(path.basename(source, ext))
          if codeExt and codeLang = config.languages?[codeExt] or languages[codeExt] or languages['text']
            lang = _.extend {}, codeLang, {literate: yes, source: ''}
        else if not lang.source
          lang.source = ext
      lang

Keep it DRY. Extract the docco **version** from `package.json`

    version = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'))).version


Command Line Interface
----------------------

Finally, let's define the interface to run Docco from the command line.
Parse options using [Commander](https://github.com/visionmedia/commander.js).

    run = (args = process.argv) ->
      c = defaults
      commander.version(version)
        .usage('[options] files')
        .option('-L, --languages [file]', 'use a custom languages.json', _.compose JSON.parse, fs.readFileSync)
        .option('-l, --layout [name]',    'choose a layout (parallel, linear, pretty or classic) or external layout', c.layout)
        .option('-o, --output [path]',    'output to a given folder', c.output)
        .option('-c, --css [file]',       'use a custom css file', c.css)
        .option('-t, --template [file]',  'use a custom .jst template', c.template)
        .option('-b, --blocks',           'parse block comments where available', c.blocks)
        .option('-e, --extension [ext]',  'assume a file extension for all inputs', c.extension)
        .option('-k, --keepext [file]',   'keep original file extension', c.keepext)
        .option('-s, --source [path]',    'output code in a given folder', c.source)
        .option('--cwd [path]',           'specify the Current Working Directory path for the purpose of generating qualified output filenames', c.cwd)
        .option('-x, --separator [sep]',  'the source path is included in the output filename, separated by this separator (default: "-")', c.separator)
        .option('-m, --marked-options [file]',  'use custom Marked options', c.marked_options)
        .option('-i, --ignore [file]',    'ignore unsupported languages', c.ignore)
        .option('-T, --tab-size [size]',      'convert leading tabs to X spaces')
        .parse(args)
        .name = "docco"
      if commander.args.length
        document commander
      else
        console.log commander.helpInformation()


Public API
----------

    Docco = module.exports = {run, document, parse, format, configure, version}


