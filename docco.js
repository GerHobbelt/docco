// Generated by CoffeeScript 2.0.0-beta3
(function() {
  var Docco, _, buildMatchers, commander, configure, defaults, document, format, fs, getLanguage, glob, highlightjs, languages, marked, parse, path, run, version, write;

  document = function(config = {}, callback) {
    return fs.mkdirs(config.output, function() {
      var complete, copyAsset, files, nextFile;
      callback || (callback = function(error) {
        if (error) {
          throw error;
        }
      });
      copyAsset = function(file, callback) {
        if (!fs.existsSync(file)) {
          return callback();
        }
        return fs.copy(file, path.join(config.output, path.basename(file)), callback);
      };
      complete = function() {
        return copyAsset(config.css, function(error) {
          if (error) {
            return callback(error);
          }
          if (fs.existsSync(config.public)) {
            return copyAsset(config.public, callback);
          }
          return callback();
        });
      };
      files = config.sources.slice();
      nextFile = function() {
        var lang, source, toDirectory, toFile;
        source = files.shift();
        if (config.flatten) {
          toDirectory = config.output;
        } else {
          toDirectory = config.root + '/' + config.output + '/' + (path.dirname(source));
        }
        if (!fs.existsSync(toDirectory)) {
          fs.mkdirsSync(toDirectory);
        }
        lang = getLanguage(source, config);
        if (lang.copy) {
          toFile = toDirectory + '/' + path.basename(source);
          console.log(`docco: ${source} -> ${toFile}`);
          return fs.copy(source, toFile, function(error, result) {
            if (error) {
              return callback(error);
            }
            if (files.length) {
              return nextFile();
            } else {
              return complete();
            }
          });
        } else {
          return fs.readFile(source, function(error, buffer) {
            var code, sections;
            if (error) {
              return callback(error);
            }
            code = buffer.toString();
            sections = parse(source, code, config);
            format(source, sections, config);
            toFile = toDirectory + '/' + (path.basename(source, path.extname(source)));
            write(source, toFile, sections, config);
            if (files.length) {
              return nextFile();
            } else {
              return complete();
            }
          });
        }
      };
      return nextFile();
    });
  };

  parse = function(source, code, config = {}) {
    var LINK_REGEX, TEXT_REGEX, codeText, docsText, hasCode, i, isText, j, k, lang, len, len1, line, lines, link, links, match, maybeCode, save, sections, text, texts;
    lines = code.split('\n');
    sections = [];
    lang = getLanguage(source, config);
    hasCode = docsText = codeText = '';
    save = function() {
      sections.push({docsText, codeText});
      return hasCode = docsText = codeText = '';
    };
    if (lang.literate) {
      isText = maybeCode = true;
      for (i = j = 0, len = lines.length; j < len; i = ++j) {
        line = lines[i];
        lines[i] = maybeCode && (match = /^([ ]{4}|[ ]{0,3}\t)/.exec(line)) ? (isText = false, line.slice(match[0].length)) : (maybeCode = /^\s*$/.test(line)) ? isText ? lang.symbol : '' : (isText = true, lang.symbol + ' ' + line);
      }
    }
    for (k = 0, len1 = lines.length; k < len1; k++) {
      line = lines[k];
      if (lang.linkMatcher && line.match(lang.linkMatcher)) {
        LINK_REGEX = /\((.+)\)/;
        TEXT_REGEX = /\[(.+)\]/;
        links = LINK_REGEX.exec(line);
        texts = TEXT_REGEX.exec(line);
        if ((links != null) && links.length > 1 && (texts != null) && texts.length > 1) {
          link = links[1];
          text = texts[1];
          codeText += '<div><img src="' + link + '"></img><p>' + text + '</p></div>' + '\n';
        }
        hasCode = true;
      } else if (lang.sectionMatcher && line.match(lang.sectionMatcher)) {
        if (hasCode) {
          save();
        }
        docsText += (line = line.replace(lang.commentMatcher, '')) + '\n';
        save();
      } else if (line.match(lang.commentMatcher) && !line.match(lang.commentFilter)) {
        if (hasCode) {
          save();
        }
        docsText += (line = line.replace(lang.commentMatcher, '')) + '\n';
        if (/^(---+|===+)$/.test(line)) {
          save();
        }
      } else {
        hasCode = true;
        codeText += line + '\n';
      }
    }
    save();
    return sections;
  };

  format = function(source, sections, config) {
    var code, i, j, language, len, markedOptions, results, section;
    language = getLanguage(source, config);
    markedOptions = {
      smartypants: true
    };
    if (config.marked) {
      markedOptions = config.marked;
    }
    marked.setOptions(markedOptions);
    marked.setOptions({
      highlight: function(code, lang) {
        lang || (lang = language.name);
        if (highlightjs.getLanguage(lang)) {
          return highlightjs.highlight(lang, code).value;
        } else {
          console.warn(`docco: couldn't highlight code block with unknown language '${lang}' in ${source}`);
          return code;
        }
      }
    });
    results = [];
    for (i = j = 0, len = sections.length; j < len; i = ++j) {
      section = sections[i];
      if (language.html) {
        section.codeHtml = section.codeText;
      } else {
        code = highlightjs.highlight(language.name, section.codeText).value;
        code = code.replace(/\s+$/, '');
        section.codeHtml = `<div class='highlight'><pre>${code}</pre></div>`;
      }
      results.push(section.docsHtml = marked(section.docsText));
    }
    return results;
  };

  write = function(source, to, sections, config) {
    var asource, asourcetToDirectory, cssPath, cssRelative, destination, first, firstSection, from, hasTitle, html, j, len, linkPath, ref, relativeLink, sourceNoExt, title, toDirectory, toExtName, toLinkBasenameNoExt, toLinkExtName, toSources;
    destination = function(file) {
      return file;
    };
    firstSection = _.find(sections, function(section) {
      return section.docsText.length > 0;
    });
    if (firstSection) {
      first = marked.lexer(firstSection.docsText)[0];
    }
    hasTitle = first && first.type === 'heading' && first.depth === 1;
    title = hasTitle ? first.text : path.basename(source);
    toDirectory = config.root + '/' + config.output + '/' + (path.dirname(source));
    toExtName = path.extname(source);
    if (toExtName !== '.jpg' && toExtName !== '.png' && toExtName !== '.tiff' && toExtName !== '.jpeg') {
      toExtName = '.html';
    }
    cssPath = path.basename(config.css);
    if (config.flatten) {
      cssRelative = cssPath;
    } else {
      cssRelative = path.relative(toDirectory, config.root + "/" + config.output + "/" + cssPath);
    }
    sourceNoExt = path.basename(source, path.extname(source));
    toSources = [];
    ref = config.sources;
    for (j = 0, len = ref.length; j < len; j++) {
      asource = ref[j];
      linkPath = path.basename(asource);
      asourcetToDirectory = config.root + '/' + config.output + '/' + (path.dirname(asource));
      toLinkBasenameNoExt = path.basename(asource, path.extname(asource));
      toLinkExtName = path.extname(asource);
      if (toExtName !== '.jpg' && toExtName !== '.png' && toExtName !== '.tiff' && toExtName !== '.jpeg') {
        toLinkExtName = '.html';
      }
      from = asourcetToDirectory + '/' + toLinkBasenameNoExt + toLinkExtName;
      if (config.flatten) {
        relativeLink = toLinkBasenameNoExt + toLinkExtName;
      } else {
        relativeLink = path.relative(to, from);
        if (relativeLink === '') {
          relativeLink = sourceNoExt;
        } else {
          relativeLink = relativeLink.slice(1);
        }
      }
      toSources.push(relativeLink);
    }
    html = config.template({
      sources: toSources,
      css: cssRelative,
      title,
      hasTitle,
      sections,
      path,
      destination
    });
    console.log(`docco: ${source} -> ${destination(to + toExtName)}`);
    return fs.writeFileSync(destination(to + toExtName), html);
  };

  defaults = {
    layout: 'parallel',
    output: 'docs',
    template: null,
    css: null,
    extension: null,
    languages: {},
    marked: null,
    setup: '.docco.json',
    help: false,
    flatten: false
  };

  configure = function(options) {
    var config, dir;
    config = _.extend({}, defaults, _.pick(options, ..._.keys(defaults)));
    config.languages = buildMatchers(config.languages);
    if (options.template) {
      if (!options.css) {
        console.warn("docco: no stylesheet file specified");
      }
      config.layout = null;
    } else {
      dir = config.layout = path.join(__dirname, 'resources', config.layout);
      if (fs.existsSync(path.join(dir, 'public'))) {
        config.public = path.join(dir, 'public');
      }
      config.template = path.join(dir, 'docco.jst');
      config.css = options.css || path.join(dir, 'docco.css');
    }
    config.template = _.template(fs.readFileSync(config.template).toString());
    if (options.marked) {
      config.marked = JSON.parse(fs.readFileSync(options.marked));
    }
    config.sources = options.args.filter(function(source) {
      var lang;
      lang = getLanguage(source, config);
      if (!lang) {
        console.warn(`docco: skipped unknown type (${path.basename(source)})`);
      }
      return lang;
    }).sort();
    return config;
  };

  _ = require('underscore');

  fs = require('fs-extra');

  path = require('path');

  marked = require('marked');

  commander = require('commander');

  highlightjs = require('highlight.js');

  path = require('path');

  glob = require('glob');

  languages = JSON.parse(fs.readFileSync(path.join(__dirname, 'resources', 'languages.json')));

  buildMatchers = function(languages) {
    var ext, l;
    for (ext in languages) {
      l = languages[ext];
      l.commentMatcher = RegExp(`^\\s*${l.symbol}\\s?`);
      l.commentFilter = /(^#![\/]|^\s*#\{)/;
      if (l.link) {
        l.linkMatcher = RegExp(`^${l.link}\\[(.+)\\]\\((.+)\\)`);
      }
      if (l.section) {
        l.sectionMatcher = RegExp(`^${l.section}\\s?`);
      }
    }
    return languages;
  };

  languages = buildMatchers(languages);

  getLanguage = function(source, config) {
    var codeExt, codeLang, ext, lang, ref;
    ext = config.extension || path.extname(source) || path.basename(source);
    lang = ((ref = config.languages) != null ? ref[ext] : void 0) || languages[ext];
    if (lang && lang.name === 'markdown') {
      codeExt = path.extname(path.basename(source, ext));
      if (codeExt && (codeLang = languages[codeExt])) {
        lang = _.extend({}, codeLang, {
          literate: true
        });
      }
    }
    return lang;
  };

  version = JSON.parse(fs.readFileSync(path.join(__dirname, 'package.json'))).version;

  run = function(args = process.argv) {
    var config, file, files, globName, j, k, len, len1, ref, setup;
    config = defaults;
    commander.version(version).usage('[options] [file]').option('-c, --css [file]', 'use a custom css file', config.css).option('-e, --extension [ext]', 'assume a file extension for all inputs', config.extension).option('-f, --flatten', 'flatten the directory hierarchy', config.flatten).option('-L, --languages [file]', 'use a custom languages.json', _.compose(JSON.parse, fs.readFileSync)).option('-l, --layout [name]', 'choose a layout (parallel, linear or classic)', config.layout).option('-m, --marked [file]', 'use custom marked options', config.marked).option('-o, --output [path]', 'output to a given folder', config.output).option('-s, --setup [file]', 'use configuration file, normally docco.json', '.docco.json').option('-t, --template [file]', 'use a custom .jst template', config.template).parse(args).name = "docco";
    config = configure(commander);
    setup = path.resolve(config.setup);
    if (fs.existsSync(setup)) {
      if (setup) {
        config = _.extend(config, JSON.parse(fs.readFileSync(setup)));
      }
    }
    config.root = process.cwd();
    if (config.sources.length !== 0) {
      files = [];
      ref = config.sources;
      for (j = 0, len = ref.length; j < len; j++) {
        globName = ref[j];
        files = _.flatten(_.union(files, glob.sync(path.resolve(config.root, globName))));
      }
      config.sources = [];
      for (k = 0, len1 = files.length; k < len1; k++) {
        file = files[k];
        config.sources.push(path.relative(config.root, file));
      }
      document(config);
    } else {
      console.log(commander.helpInformation());
    }
  };

  Docco = module.exports = {run, document, parse, format, version};

}).call(this);

//# sourceMappingURL=docco.js.map
