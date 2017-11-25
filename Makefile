
# ** TOOLS **

# 'cake' is not 'cake' on Ubuntu but 'cake.coffeescript'.
# Anyhow, we are now using a local (modern!) install of Cake, so the problem is moot.
#CAKE=cake.coffeescript
CAKE=node_modules/.bin/cake
COFFEE=node_modules/.bin/coffee
# linear | parallel | pretty | plain-markdown | classic | ivory
TEMPLATE=custom



# ** COMMON DEPENDENCIES **

SRC_DEPS=                                       \
		Makefile                                \
		Cakefile                                \
		package.json                            \
		docco.litcoffee

TOOL_DEPS=                                      \
		$(CAKE)                                 \
		$(COFFEE)



# ** MAIN BUILD TARGETS **

.PHONY: all install build doc loc clean test

all: build doc loc test

install: build doc loc
	$(CAKE) install

build: docco.js test/tests.js

doc: index.html

loc: $(SRC_DEPS) $(TOOL_DEPS)
	$(CAKE) loc

test: test/tests.js
	node test/tests.js 

clean:
	-rm index.html
	-rm docco.js

superclean: clean
	-rm -rf node_modules



# ** ASSISTANT/SUBSERVIENT BUILD TARGETS **

docco.js: $(SRC_DEPS) $(TOOL_DEPS)
	$(COFFEE) -c docco.litcoffee
	#$(CAKE) build

index.html: $(SRC_DEPS) $(TOOL_DEPS)
	bin/docco --layout $(TEMPLATE) docco.litcoffee
	sed -e 's/docco.css/resources\/$(TEMPLATE)\/docco.css/g' < docs/docco.html > index.html
	rm -rf docs
	#$(CAKE) doc

test/tests.js: $(SRC_DEPS) $(TOOL_DEPS) test/tests.coffee docco.js
	$(COFFEE) -c test/tests.coffee

# did 'npm install' run before?
$(TOOL_DEPS):
	@echo "*** Installing NodeJS / Cake dependencies for Docco ***"
	npm install

