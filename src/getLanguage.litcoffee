
    path = require 'path'

A function to get the current language we're documenting, based on the
file extension. Detect and tag "literate" `.ext.md` variants.

    getLanguage = (source, languages, config) ->
      ext  = config.extension or path.extname(source) or path.basename(source)
      lang = config.languages?[ext] or languages[ext]
      if lang and lang.name is 'markdown'
        codeExt = path.extname(path.basename(source, ext))
        if codeExt and codeLang = languages[codeExt]
          lang = _.extend {}, codeLang, {literate: yes}
      lang

    module.exports = getLanguage