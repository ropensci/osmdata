LFILE = README
VIGNETTE = osmdata

all: help

init: ## Initialize `pkgdown` site
	echo "pkgdown::init_site()" | R --no-save -q

vignette: ## Render vignette defined at top of `makefile`
	echo "pkgdown::build_article('$(VIGNETTE)',quiet=FALSE)" | R --no-save -q

site: ## Build entire `pkgdown` site
	echo "pkgdown::build_site()" | R --no-save -q

knith: $(LFILE).Rmd ## Render readme to HTML
	echo "rmarkdown::render('$(LFILE).Rmd',output_file='$(LFILE).html')" | R --no-save -q

knitr: $(LFILE).Rmd ## Render `REAMDE.Rds` to `README.md`.
	echo "rmarkdown::render('$(LFILE).Rmd',output_format=rmarkdown::md_document(variant='gfm'))" | R --no-save -q

open: ## Open HTML-rendered vignette
	xdg-open docs/index.html &

check: ## Run `rcmdcheck`
	Rscript -e 'rcmdcheck::rcmdcheck()'

test: ## Run test suite
	Rscript -e 'devtools::load_all(); testthat::test_local()'

pkgcheck: ## Run `pkgcheck` and print results to screen.
	Rscript -e 'library(pkgcheck); checks <- pkgcheck(); print(checks); summary (checks)'

allcontribs: ## Update 'allcontributors' list on README
	Rscript -e 'allcontributors::add_contributors (check_urls = FALSE)'

clean: ## Clean all temp and cached files
	rm -rf *.html *.png README_cache 

help: ## Show this help
	@printf "Usage:\033[36m make [target]\033[0m\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Phony targets:
.PHONY: doc
.PHONY: check
.PHONY: help
