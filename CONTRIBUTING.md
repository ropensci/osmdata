# Contributing to osmdata

## Opening issues

The easiest way to note any behavioural curiosities or to request any new
features is by opening a [github issue](https://github.com/ropensci/osmdata/issues).


## Development guidelines

If you'd like to contribute changes to `osmdata`, we use [the GitHub
flow](https://guides.github.com/introduction/flow/index.html) for proposing,
submitting, reviewing, and accepting changes. If you haven't done this before,
there's a nice overview of git [here](http://r-pkgs.had.co.nz/git.html), as well
as best practices for submitting pull requests
[here](http://r-pkgs.had.co.nz/git.html#pr-make).

The `osmdata` coding style diverges somewhat from [this commonly used R style
guide](http://adv-r.had.co.nz/Style.html), primarily in the following two ways,
both of which improve code readability: (1) All curly braces are vertically
aligned:

```r
this <- function ()
{
    x <- 1
}
```
and **not**
```r
this <- function(){
    x <- 1
}
```
and (2) Also highlighted in that code is the additional whitespace which
permeates `osmdata` code. Words of text are separated by whitespace, and so
code words should be too:
```r
this <- function1 (function2 (x))
```
and **not**
```r
this <- function1(function2(x))
```
with the natural result that one ends up writing
```r
this <- function ()
```
with a space between `function` and `()`. That's it.

You can use `precommit::use_precommit()` to enforce this style with git commit 
hooks as defined in `.pre-commit-config.yaml`. The first commit can be slow
because the hooks have to be compiled and installed. To commit ignoring hooks,
`git commit --no-verify`, or shortened version, `git commit -n`.

## Maintenance

To refresh the `README.md` file after modifying `README.Rmd`, use:
```r
devtools::build_readme(output_format="md_document")
```

When updating the package dependencies in `DESCRIPTION` or other metadata,
refresh `codemeta.json`:
```r
codemetar::write_codemeta()
```

## Code of Conduct

We want to encourage a warm, welcoming, and safe environment for contributing to
this project. See the [code of
conduct](https://github.com/ropensci/.github/blob/master/CODE_OF_CONDUCT.md) for
more information.
